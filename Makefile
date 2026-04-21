.PHONY: lint test fixtures clean help

FIXTURE_ROLE := tests/fixtures/sample_role

## Quality

lint: ## yamllint action.yml + workflows + fixtures (dockerized, no host install)
	docker run --rm -v $$(pwd):/data cytopia/yamllint -d relaxed action.yml .github/workflows/ tests/

## Testing

test: ## Run molecule against the fixture role (requires python + docker locally)
	cd $(FIXTURE_ROLE) && MOLECULE_DISTRO=$${MOLECULE_DISTRO:-ubuntu2404} molecule test

fixtures: ## List fixture files (role is committed — nothing to generate)
	@ls -R $(FIXTURE_ROLE)

## Cleanup

clean: ## Remove molecule caches
	rm -rf $(FIXTURE_ROLE)/.molecule $(FIXTURE_ROLE)/*.retry

## Help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
