package common

import (
	"encoding/json"
	"fmt"
)

func Cast[T any](src any) (T, error) {
	var dst T

	b, err := json.Marshal(src)
	if err != nil {
		return dst, fmt.Errorf("failed to marshal: %w", err)
	}
	if err := json.Unmarshal(b, &dst); err != nil {
		return dst, fmt.Errorf("failed to unmarshal: %w", err)
	}

	return dst, nil
}
