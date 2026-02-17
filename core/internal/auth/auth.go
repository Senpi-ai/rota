package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/alpkeskin/rota/core/pkg/logger"
	"github.com/golang-jwt/jwt/v5"
)

// PrivyClaims represents the JWT claims for a Privy access token.
type PrivyClaims struct {
	AppId      string `json:"aud,omitempty"`
	Expiration int64  `json:"exp,omitempty"` // seconds since epoch (handles JSON number)
	Issuer     string `json:"iss,omitempty"`
	UserId     string `json:"sub,omitempty"`
	jwt.RegisteredClaims
}

// Valid checks that the claims are valid for the given Privy app ID.
func (c *PrivyClaims) Valid(privyAppID string) error {
	if c.AppId != privyAppID {
		return errors.New("aud claim must be your Privy App ID")
	}
	if c.Issuer != "privy.io" {
		return errors.New("iss claim must be 'privy.io'")
	}
	now := time.Now().Unix()
	if c.Expiration > 0 && c.Expiration < now {
		return errors.New("token is expired")
	}
	return nil
}

// normalizePEM ensures the PEM string has newlines so ParseECPublicKeyFromPEM accepts it (e.g. when stored single-line in env).
func normalizePEM(pem string) string {
	if strings.Contains(pem, "\n") {
		return pem
	}
	// Single-line PEM: insert newline after BEGIN and before END
	pem = strings.Replace(pem, "-----BEGIN PUBLIC KEY-----", "-----BEGIN PUBLIC KEY-----\n", 1)
	pem = strings.Replace(pem, "-----END PUBLIC KEY-----", "\n-----END PUBLIC KEY-----", 1)
	return pem
}

// keyFunc returns a jwt.Keyfunc that verifies ES256 and uses the given PEM-encoded EC public key.
func keyFunc(verificationKeyPEM string) jwt.Keyfunc {
	return func(token *jwt.Token) (interface{}, error) {
		if token.Method.Alg() != "ES256" {
			return nil, fmt.Errorf("unexpected JWT signing method: %v", token.Header["alg"])
		}
		return jwt.ParseECPublicKeyFromPEM([]byte(normalizePEM(verificationKeyPEM)))
	}
}

// Authorize validates a Privy access token locally using ES256 signature verification and claims (aud, iss, exp).
// privyAppID and verificationKeyPEM must both be non-empty when auth is enabled.
// Returns: privyId (user's Privy DID / sub claim), isAuthorised (bool), error
func Authorize(ctx context.Context, authToken, privyAppID, verificationKeyPEM string, log *logger.Logger) (string, bool, error) {
	if authToken == "" {
		return "", false, fmt.Errorf("auth token is empty")
	}
	if privyAppID == "" || verificationKeyPEM == "" {
		return "", false, fmt.Errorf("privy app ID and verification key are required for token validation")
	}

	token, err := jwt.ParseWithClaims(authToken, &PrivyClaims{}, keyFunc(verificationKeyPEM))
	if err != nil {
		log.Debug("JWT parse or signature verification failed", "error", err)
		return "", false, fmt.Errorf("token verification failed: %w", err)
	}

	privyClaims, ok := token.Claims.(*PrivyClaims)
	if !ok {
		return "", false, fmt.Errorf("invalid token claims type")
	}

	if err := privyClaims.Valid(privyAppID); err != nil {
		log.Debug("token claims validation failed", "error", err)
		return "", false, fmt.Errorf("token validation failed: %w", err)
	}

	// Prefer UserId (sub); fallback for older token shapes
	privyID := privyClaims.UserId
	if privyID == "" {
		privyID = privyClaims.Subject
	}
	if privyID == "" {
		return "", false, fmt.Errorf("privy ID not found in token claims")
	}

	return privyID, true, nil
}

// ExtractBearerToken extracts the Bearer token from Authorization header.
func ExtractBearerToken(authHeader string) string {
	if authHeader == "" {
		return ""
	}
	parts := strings.Split(authHeader, " ")
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return ""
	}
	return parts[1]
}
