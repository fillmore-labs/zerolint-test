package repo

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
)

type Repo[T any] map[string]T

func (r *Repo[T]) Read(name string) error {
	repo, err := ReadAll[T](name)
	if err != nil {
		return err
	}

	*r = repo

	return nil
}

func (r Repo[T]) Write(name string) error {
	return WriteAll(name, r)
}

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
