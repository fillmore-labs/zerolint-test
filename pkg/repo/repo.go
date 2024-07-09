package repo

import (
	"encoding/json"
	"fmt"
	"os"
)

func ReadAll(name string) (map[string]string, error) {
	repos, err := os.Open(name)
	if err != nil {
		return nil, err
	}
	defer repos.Close()

	var ret map[string]string
	if err := json.NewDecoder(repos).Decode(&ret); err != nil {
		return nil, fmt.Errorf("can't decode %s: %w", name, err)
	}

	return ret, err
}
