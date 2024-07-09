#!/bin/sh

go run ./cmd/prepare

rm -Rf temp/argoproj temp/traefik
