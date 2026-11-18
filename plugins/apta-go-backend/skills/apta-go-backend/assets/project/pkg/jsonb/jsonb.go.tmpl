package jsonb

import (
	"encoding/json"

	"gorm.io/datatypes"
)

type JSONB[T any] struct {
	datatypes.JSON
}

func New[T any](data T) (JSONB[T], error) {
	var j JSONB[T]

	b, err := json.Marshal(data)
	if err != nil {
		return j, err
	}

	err = j.UnmarshalJSON(b)

	return j, err
}

func (j JSONB[T]) Deserialize() (T, error) {
	var s T
	jsonData, err := j.MarshalJSON()
	if err != nil {
		return s, err
	}
	if err := json.Unmarshal(jsonData, &s); err != nil {
		return s, err
	}

	return s, nil
}
