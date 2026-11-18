package arrays

type reduceFunc[TSlice any, TResult any] func(total TResult, currentValue TSlice) TResult
type mapFunc[TSlice any, TResult any] func(currentValue TSlice) TResult

func Reduce[TSlice any, TResult any](s []TSlice, initialValue TResult, cb reduceFunc[TSlice, TResult]) TResult {
	total := initialValue
	for _, currentValue := range s {
		total = cb(total, currentValue)
	}

	return total
}

func Map[TSlice any, TResult any](s []TSlice, cb mapFunc[TSlice, TResult]) []TResult {
	var result []TResult
	for _, currentValue := range s {
		elem := cb(currentValue)
		result = append(result, elem)
	}

	return result
}

func Filter[TSlice any](s []TSlice, cb func(currentValue TSlice) bool) []TSlice {
	result := make([]TSlice, 0)
	for _, currentValue := range s {
		if cb(currentValue) {
			result = append(result, currentValue)
		}
	}

	return result
}

func Find[TSlice any](s []TSlice, cb func(currentValue TSlice) bool) *TSlice {
	for _, currentValue := range s {
		if cb(currentValue) {
			return &currentValue
		}
	}

	return nil
}

func DiffCheck[T comparable](a []T, b []T) (aDiff, bDiff []T) {
	aMap := make(map[T]bool)
	bMap := make(map[T]bool)

	for _, v := range a {
		aMap[v] = true
	}

	// Mark all new elements
	for _, v := range b {
		bMap[v] = true
	}

	// Find items in old but not in new
	for _, v := range a {
		if !bMap[v] {
			aDiff = append(aDiff, v)
		}
	}

	// Find items in new but not in old
	for _, v := range b {
		if !aMap[v] {
			bDiff = append(bDiff, v)
		}
	}

	return
}
