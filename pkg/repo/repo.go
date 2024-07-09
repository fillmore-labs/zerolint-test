package repo

import (
	_ "embed"
	"encoding/json"
	"log"
)

//go:embed repos.json
var repos []byte

func ReadAll() map[string]string {
	var ret map[string]string
	if err := json.Unmarshal(repos, &ret); err != nil {
		log.Fatal(err)
	}

	return ret
}
