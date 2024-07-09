package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"

	"fillmore-labs.com/zerolint-test/pkg/repo"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/config"
	"github.com/go-git/go-git/v5/plumbing"
)

const reposJSON = "repos.json"

type commit struct {
	Tag    string `json:"tag,omitempty"`
	Branch string `json:"branch,omitempty"`
	SHA    string `json:"sha,omitempty"`
}

func main() {
	repos, err := repo.ReadAll[commit](reposJSON)
	if err != nil {
		log.Fatal(err)
	}

	var remove []string

	ctx := context.Background()
	for k, v := range repos {
		dir := "./temp/" + k
		info, err := os.Stat(dir)

		if err == nil && info.IsDir() {
			updated, err := handleRepo(ctx, dir, k, v)
			if err != nil {
				log.Println("handle", k, ": ", err)

				break
			}

			if updated {
				remove = append(remove, k)
			}

			continue
		} else if errors.Is(err, os.ErrNotExist) {
			fmt.Printf("Checking out %s %s\n", k, v.Tag)
			if err := handleNonexistant(ctx, dir, k, v); err != nil {
				log.Println(k, ": ", err)

				break
			}
		}
	}

	for _, r := range remove {
		fmt.Printf("rm logs/%s_*.log\n", strings.Replace(r, "/", "_", 1))
	}
}

func handleRepo(ctx context.Context, dir, _ string, v commit) (bool, error) {
	repo, err := git.PlainOpen(dir)
	if err != nil {
		return false, fmt.Errorf("open: %w", err)
	}

	tree, err := repo.Worktree()
	if err != nil {
		return false, fmt.Errorf("worktree: %w", err)
	}

	head, err := repo.Head()
	if err != nil {
		return false, fmt.Errorf("head: %w", err)
	}

	if head.Hash().String() == v.SHA {
		if err := tree.Reset(&git.ResetOptions{
			Mode: git.HardReset,
		}); err != nil {
			return false, fmt.Errorf("reset: %w", err)
		}

		return false, nil
	}

	fmt.Println("updating:", dir, head.Hash().String(), "=>", v.SHA)

	refSpec := config.RefSpec("+" + v.SHA + ":" + v.SHA)

	err = repo.FetchContext(ctx, &git.FetchOptions{
		RefSpecs: []config.RefSpec{refSpec},
		Progress: os.Stdout,
		Force:    true,
	})
	if err != nil && err != git.NoErrAlreadyUpToDate {
		return false, fmt.Errorf("fetch: %w", err)
	}

	checkoutOptions := checkoutOptions(v)
	checkoutOptions.Force = true

	if err := tree.Checkout(&checkoutOptions); err != nil {
		return false, fmt.Errorf("checkout: %w", err)
	}

	return true, nil
}

const perm = 0o775

func handleNonexistant(ctx context.Context, dir, k string, v commit) error {
	if err := os.MkdirAll(dir, perm); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}

	cloneOptions := git.CloneOptions{
		URL:        fmt.Sprintf("https://github.com/%s.git", k),
		NoCheckout: true,
		Progress:   os.Stdout,
	}

	r, err := git.PlainCloneContext(ctx, dir, false, &cloneOptions)
	if err != nil {
		return fmt.Errorf("plainclone: %w", err)
	}

	tree, err := r.Worktree()
	if err != nil {
		return fmt.Errorf("worktree: %w", err)
	}

	checkoutOptions := checkoutOptions(v)

	if err := tree.Checkout(&checkoutOptions); err != nil {
		return fmt.Errorf("checkout: %w", err)
	}

	return nil
}

func checkoutOptions(v commit) git.CheckoutOptions {
	checkoutOptions := git.CheckoutOptions{}

	switch {
	case v.SHA != "":
		checkoutOptions.Hash = plumbing.NewHash(v.SHA)

	case v.Tag != "":
		checkoutOptions.Branch = plumbing.NewTagReferenceName(v.Tag)

	case v.Branch != "":
		checkoutOptions.Branch = plumbing.NewBranchReferenceName(v.Branch)

	default:
		checkoutOptions.Branch = plumbing.HEAD
	}

	return checkoutOptions
}
