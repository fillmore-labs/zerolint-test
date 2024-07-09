package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"

	"fillmore-labs.com/zerolint-test/pkg/repo"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
)

func main() {
	ctx := context.Background()
	repos := repo.ReadAll()

	for k, v := range repos {
		dir := "./temp/" + k
		if _, err := os.Stat(dir); !errors.Is(err, os.ErrNotExist) {
			continue
		}

		fmt.Printf("Checking out %s %s\n", k, v)
		if err := os.MkdirAll(dir, 0o775); err != nil { //nolint:mnd
			log.Fatal(err)
		}

		options := git.CloneOptions{
			URL:          fmt.Sprintf("https://github.com/%s.git", k),
			SingleBranch: true,
			Depth:        1,
			Progress:     os.Stdout,
		}

		switch {
		case len(v) == 0:
			options.ReferenceName = plumbing.HEAD

		case v[0] == '&':
			options.ReferenceName = plumbing.NewBranchReferenceName(v[1:])

		default:
			options.ReferenceName = plumbing.NewTagReferenceName(v)
		}

		if _, err := git.PlainCloneContext(ctx, dir, false, &options); err != nil {
			log.Fatal(err)
		}
	}
}
