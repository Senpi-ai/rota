package auth

import (
	"context"
	"testing"

	"github.com/alpkeskin/rota/core/pkg/logger"
)

func TestExtractBearerToken(t *testing.T) {
	tests := []struct {
		name     string
		header   string
		expected string
	}{
		{"empty", "", ""},
		{"only Bearer", "Bearer", ""},
		{"valid", "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6cHJpdnk6dGVzdCJ9.x", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6cHJpdnk6dGVzdCJ9.x"},
		{"lowercase bearer", "bearer token123", "token123"},
		{"no space", "Bearertoken", ""},
		{"wrong scheme", "Basic dXNlcjpwYXNz", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractBearerToken(tt.header)
			if got != tt.expected {
				t.Errorf("ExtractBearerToken(%q) = %q, want %q", tt.header, got, tt.expected)
			}
		})
	}
}

func TestAuthorize_EmptyToken(t *testing.T) {
	log := logger.New("error")
	privyID, ok, err := Authorize(context.Background(), "", "", "", log)
	if err == nil || ok || privyID != "" {
		t.Errorf("Authorize(empty token) want error and !ok; got privyID=%q ok=%v err=%v", privyID, ok, err)
	}
}

func TestAuthorize_InvalidTokenFormat(t *testing.T) {
	log := logger.New("error")
	privyID, ok, err := Authorize(context.Background(), "not-three-parts", "", "", log)
	if err == nil || ok || privyID != "" {
		t.Errorf("Authorize(invalid format) want error and !ok; got privyID=%q ok=%v err=%v", privyID, ok, err)
	}
}

func TestAuthorize_InvalidPayload(t *testing.T) {
	log := logger.New("error")
	// Three parts but middle is not valid base64 JSON
	token := "a." + "not-valid-base64!!" + ".c"
	privyID, ok, err := Authorize(context.Background(), token, "", "", log)
	if err == nil || ok || privyID != "" {
		t.Errorf("Authorize(invalid payload) want error and !ok; got privyID=%q ok=%v err=%v", privyID, ok, err)
	}
}

func TestGetPrivyDID(t *testing.T) {
	ctx := context.Background()
	if got := GetPrivyDID(ctx); got != "" {
		t.Errorf("GetPrivyDID(empty ctx) = %q, want \"\"", got)
	}
	ctxWith := context.WithValue(ctx, PrivyDIDKey, "did:privy:abc")
	if got := GetPrivyDID(ctxWith); got != "did:privy:abc" {
		t.Errorf("GetPrivyDID(ctx with value) = %q, want \"did:privy:abc\"", got)
	}
}
