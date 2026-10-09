package common_test

import (
	"testing"

	"github.com/devapta/shop-api/internal/common"
	"github.com/stretchr/testify/assert"
)

func TestCast(t *testing.T) {
	type src struct {
		Name string `json:"name"`
	}
	type dst struct {
		Name string `json:"name"`
	}

	got, err := common.Cast[dst](src{Name: "apta"})

	assert.NoError(t, err)
	assert.Equal(t, dst{Name: "apta"}, got)
}
