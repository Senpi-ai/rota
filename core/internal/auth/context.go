package auth

import "context"

type contextKey string

const (
	// PrivyDIDKey is the context key for the authenticated user's Privy DID.
	PrivyDIDKey contextKey = "privy_did"
)

// GetPrivyDID returns the Privy DID from the context, or empty string if not set.
func GetPrivyDID(ctx context.Context) string {
	if v := ctx.Value(PrivyDIDKey); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
