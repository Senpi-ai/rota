package services

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/alpkeskin/rota/core/internal/proxy"
	"github.com/alpkeskin/rota/core/internal/repository"
	"github.com/alpkeskin/rota/core/pkg/logger"
)

// HealthCheckRetestService schedules retesting of failed proxies.
type HealthCheckRetestService struct {
	settingsRepo  *repository.SettingsRepository
	healthChecker *proxy.HealthChecker
	ticker        *time.Ticker
	stopChan      chan struct{}
	mu            sync.Mutex
	running       bool
	logger        *logger.Logger
}

// NewHealthCheckRetestService creates a new HealthCheckRetestService.
func NewHealthCheckRetestService(
	settingsRepo *repository.SettingsRepository,
	healthChecker *proxy.HealthChecker,
	log *logger.Logger,
) *HealthCheckRetestService {
	return &HealthCheckRetestService{
		settingsRepo:  settingsRepo,
		healthChecker: healthChecker,
		stopChan:      make(chan struct{}),
		logger:        log,
	}
}

// Start starts the retest scheduler if enabled in settings.
func (s *HealthCheckRetestService) Start(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.running {
		return nil
	}

	settings, err := s.settingsRepo.GetAll(ctx)
	if err != nil {
		return fmt.Errorf("failed to get settings: %w", err)
	}

	if settings.HealthCheck.RetestFailedAfterMinutes <= 0 {
		s.logger.Info("healthcheck retest disabled (retest_failed_after_minutes is 0)")
		return nil
	}

	s.running = true
	s.ticker = time.NewTicker(time.Minute)
	s.logger.Info("healthcheck retest scheduler started", "interval", time.Minute)

	go s.run(ctx)

	// Run once on start to catch eligible failed proxies
	go s.runRetest(ctx)

	return nil
}

// Stop stops the retest scheduler.
func (s *HealthCheckRetestService) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.running {
		return
	}

	s.running = false
	if s.ticker != nil {
		s.ticker.Stop()
	}
	close(s.stopChan)
	s.logger.Info("healthcheck retest scheduler stopped")
}

// run is the main scheduler loop.
func (s *HealthCheckRetestService) run(ctx context.Context) {
	for {
		select {
		case <-s.ticker.C:
			s.runRetest(ctx)
		case <-s.stopChan:
			return
		case <-ctx.Done():
			return
		}
	}
}

func (s *HealthCheckRetestService) runRetest(ctx context.Context) {
	settings, err := s.settingsRepo.GetAll(ctx)
	if err != nil {
		s.logger.Error("failed to get settings for failed proxy retest", "error", err)
		return
	}

	retestAfter := settings.HealthCheck.RetestFailedAfterMinutes
	if retestAfter <= 0 {
		return
	}

	results, err := s.healthChecker.CheckFailedProxies(ctx, retestAfter)
	if err != nil {
		s.logger.Error("failed proxy retest run failed", "error", err)
		return
	}

	if len(results) > 0 {
		s.logger.Info("failed proxy retest run completed", "tested", len(results))
	}
}
