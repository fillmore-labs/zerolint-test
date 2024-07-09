package repo

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
)

// ReadAll ....
func ReadAll[T any](name string) (map[string]T, error) {
	repos, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	defer repos.Close()

	var ret map[string]T
	if err := json.NewDecoder(repos).Decode(&ret); err != nil {
		return nil, fmt.Errorf("can't decode %s: %w", name, err)
	}

	return ret, nil
}

// WriteAll ....
func WriteAll[T any](name string, repo map[string]T) error {
	var buf bytes.Buffer

	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "    ")
	enc.SetEscapeHTML(false)

	if err := enc.Encode(repo); err != nil {
		return err
	}

	return os.WriteFile(name, buf.Bytes(), 0o644) //nolint:mnd
}
