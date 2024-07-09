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

const reposJSON = "repos.json"

func main() {
	repos, err := repo.ReadAll[string](reposJSON)
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	for k, v := range repos {
		ref := valueToRef(v)
		dir := "./temp/" + k
		info, err := os.Stat(dir)

		if err == nil && info.IsDir() {
			if err := handleRepo(ctx, dir, k, ref); err != nil {
				log.Fatal(k, ": ", err)
			}

			continue
		}

		if !errors.Is(err, os.ErrNotExist) {
			continue
		}

		fmt.Printf("Checking out %s %s\n", k, v)
		if err := handleNonexistant(ctx, dir, k, ref); err != nil {
			log.Fatal(k, ": ", err)
		}
	}
}

func valueToRef(v string) plumbing.ReferenceName {
	switch {
	case len(v) == 0:
		return plumbing.HEAD

	case v[0] == '&':
		return plumbing.NewBranchReferenceName(v[1:])

	default:
		return plumbing.NewTagReferenceName(v)
	}
}

func handleRepo(_ context.Context, dir, _ string, _ plumbing.ReferenceName) error {
	repo, err := git.PlainOpen(dir)
	if err != nil {
		return fmt.Errorf("%w", err)
	}

	tree, err := repo.Worktree()
	if err != nil {
		return fmt.Errorf("%w", err)
	}

	if err := tree.Reset(&git.ResetOptions{Mode: git.HardReset}); err != nil {
		return fmt.Errorf("%w", err)
	}

	return nil
}

const perm = 0o775

func handleNonexistant(ctx context.Context, dir, k string, ref plumbing.ReferenceName) error {
	if err := os.MkdirAll(dir, perm); err != nil {
		return fmt.Errorf("%w", err)
	}

	options := git.CloneOptions{
		URL:           fmt.Sprintf("https://github.com/%s.git", k),
		SingleBranch:  true,
		ReferenceName: ref,
		Depth:         1,
		Progress:      os.Stdout,
	}

	if _, err := git.PlainCloneContext(ctx, dir, false, &options); err != nil {
		return fmt.Errorf("%w", err)
	}

	return nil
}
