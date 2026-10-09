package common_test

import (
	"testing"

	"github.com/devapta/inventory-api/internal/common"
	"github.com/devapta/inventory-api/internal/configs"
	"github.com/stretchr/testify/assert"
)

func TestGenerateAndParseJWT(t *testing.T) {
	t.Setenv("JWT_SECRET", "test-secret")
	t.Setenv("JWT_EXPIRY_MINUTES", "5")
	configs.SetupENV()

	at, rt, err := common.GenerateJWTPair(map[string]any{"userId": 1}, []string{"users#read"}, false)
	assert.NoError(t, err)

	claims, err := common.ParseToken(at)
	assert.NoError(t, err)
	assert.EqualValues(t, 1, claims["userId"])

	perms, err := common.ParseClaimsToStringSlice(claims["permissions"])
	assert.NoError(t, err)
	assert.Equal(t, []string{"users#read"}, perms)

	rtClaims, err := common.ParseToken(rt)
	assert.NoError(t, err)
	assert.Equal(t, false, rtClaims["isRemember"])
}
