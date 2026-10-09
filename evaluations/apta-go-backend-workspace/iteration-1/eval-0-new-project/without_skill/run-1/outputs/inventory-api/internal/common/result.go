package common

import (
	"errors"
	"net/http"

	"github.com/devapta/inventory-api/internal/enums"
	"gorm.io/gorm"
)

type Result[T any] struct {
	Items     T      `json:"items"`
	IsSuccess bool   `json:"isSuccess"`
	Message   string `json:"message"`
}

func ResultOk[T any](items T, message string) Result[T] {
	return Result[T]{
		Items:     items,
		IsSuccess: true,
		Message:   message,
	}
}

func ResultErr(err error, message string) (int, Result[string]) {
	if message == "" {
		message = err.Error()
	}

	return StatusCodeFromError(err), Result[string]{
		Items:     err.Error(),
		IsSuccess: false,
		Message:   message,
	}
}

func StatusCodeFromError(err error) int {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return http.StatusNotFound
	}

	if errors.Is(err, enums.ErrAlreadyRegsitered) {
		return http.StatusUnauthorized
	}

	return http.StatusInternalServerError
}
