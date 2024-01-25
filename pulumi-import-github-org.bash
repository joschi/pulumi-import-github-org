#!/usr/bin/env bash

if [[ -n "${DEBUG}" ]]; then
	set -x
	GH_DEBUG=1
	export GH_DEBUG
fi

set -euo pipefail

ORG=${ORG:-''}
GH_BIN=${GH_BIN:-'gh'}
PULUMI_BIN=${PULUMI_BIN:-'pulumi'}

if ! command -v "${GH_BIN}" &>/dev/null; then
	echo "Please install GitHub CLI: https://cli.github.com/" >&2
	exit 1
fi

if ! command -v "${PULUMI_BIN}" &>/dev/null; then
	echo "Please install Pulumi: https://www.pulumi.com/docs/install/" >&2
	exit 1
fi

CREATE_NEW_PROJECT=
PROJECT_DIR=$PWD
PROJECT_DIR_PARAM=
while getopts "nd:o:" opt; do
	case $opt in
	n)
		CREATE_NEW_PROJECT=1
		;;
	o)
		ORG=${OPTARG}
		;;
	d)
		PROJECT_DIR=${OPTARG}
		PROJECT_DIR_PARAM=("--dir" "${PROJECT_DIR}")
		;;
	*)
		echo "Invalid command line flags" >&2
		exit 1
		;;
	esac
done

if [[ -z "${ORG}" ]]; then
	echo "Please provide the GitHub organization via the -o parameter or the \$ORG environment variable." >&2
	exit 1
else
	echo "* Importing resources from GitHub organization \"${ORG}\""
fi

PULUMI_TEMPLATE="github-typescript"
if [[ -n "${CREATE_NEW_PROJECT}" ]]; then
	echo "* Creating new Pulumi project based on template ${PULUMI_TEMPLATE}"
	${PULUMI_BIN} new "${PULUMI_TEMPLATE}" "${PROJECT_DIR_PARAM[@]}" --config "github:owner=${ORG}"

	# Install Pulumi GitHub provider 5.x
	pushd "${PROJECT_DIR}"
	npm install "@pulumi/github@^5.0"
	popd
fi

TEMP_DIR=$(mktemp -d)

# https://www.pulumi.com/registry/packages/github/api-docs/organizationsettings/
gh api --paginate "orgs/${ORG}" -q "{\"type\":\"github:index/organizationSettings:OrganizationSettings\",\"name\":\"orgSettings-${ORG}\",\"id\": .id | tostring}" >"${TEMP_DIR}/gh-org.json"
# https://www.pulumi.com/registry/packages/github/api-docs/organizationblock/
gh api --paginate "orgs/${ORG}/blocks" -q "{\"type\":\"github:index/organizationBlock:OrganizationBlock\",\"name\":\"orgBlock-${ORG}\",\"id\": .id | tostring}" >"${TEMP_DIR}/gh-org-blocks.json"
# https://www.pulumi.com/registry/packages/github/api-docs/organizationruleset/
gh api --paginate "orgs/${ORG}/rulesets" -q "{\"type\":\"github:index/organizationRuleset:OrganizationRuleset\",\"name\":\"orgRuleset-${ORG}\",\"id\": .id | tostring}" >"${TEMP_DIR}/gh-org-rulesets.json"
# https://www.pulumi.com/registry/packages/github/api-docs/organizationwebhook/
gh api --paginate "orgs/${ORG}/hooks" -q "{\"type\":\"github:index/organizationWebhook:OrganizationWebhook\",\"name\":\"orgWebhook-${ORG}\",\"id\": .id | tostring}" >"${TEMP_DIR}/gh-org-webhooks.json"
# https://www.pulumi.com/registry/packages/github/api-docs/organizationsecuritymanager/
gh api --paginate "orgs/${ORG}/security-managers" -q "{\"type\":\"github:index/organizationSecurityManager:OrganizationSecurityManager\",\"name\":\"orgSecurityManager-${ORG}\",\"id\": .id | tostring}" >"${TEMP_DIR}/gh-org-security-managers.json"
# https://www.pulumi.com/registry/packages/github/api-docs/membership/
gh api --paginate "orgs/${ORG}/members" -q ".[] | {\"type\":\"github:index/membership:Membership\",\"name\": (\"member-\" + .login), \"id\": (\"${ORG}:\" + .login) }" >"${TEMP_DIR}/gh-membership.json"

# https://www.pulumi.com/registry/packages/github/api-docs/team/
gh api --paginate "orgs/${ORG}/teams" -q ".[] | {\"type\":\"github:index/team:Team\",\"name\": (\"team-\" + .slug), \"id\": .id | tostring}" >"${TEMP_DIR}/gh-team.json"
# https://www.pulumi.com/registry/packages/github/api-docs/teamsettings/
gh api --paginate "orgs/${ORG}/teams" -q ".[] | {\"type\":\"github:index/teamSettings:TeamSettings\",\"name\": (\"teamSettings-\" + .slug), \"id\": .id | tostring}" >"${TEMP_DIR}/gh-teamsettings.json"
# https://www.pulumi.com/registry/packages/github/api-docs/teammembers/
gh api --paginate "orgs/${ORG}/teams" -q ".[] | {\"type\":\"github:index/teamMembers:TeamMembers\",\"name\": (\"teamMembers-\" + .slug), \"id\": .id | tostring}" >"${TEMP_DIR}/gh-teammembers.json"
# https://www.pulumi.com/registry/packages/github/api-docs/teamsyncgroupmapping/
gh api --paginate "orgs/${ORG}/teams" -q ".[] | {\"type\":\"github:index/teamSyncGroupMapping:TeamSyncGroupMapping\",\"name\": (\"teamSyncGroupMapping-\" + .slug), \"id\": .id | tostring}" >"${TEMP_DIR}/gh-teamsyncgroupmapping.json"

# https://www.pulumi.com/registry/packages/github/api-docs/repository/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/repository:Repository\",\"name\": (\"repository-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-repository.json"
# https://www.pulumi.com/registry/packages/github/api-docs/issuelabels/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/issueLabels:IssueLabels\",\"name\": (\"labels-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-issuelabels.json"
# https://www.pulumi.com/registry/packages/github/api-docs/branchdefault/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/branchDefault:BranchDefault\",\"name\": (\"branchDefault-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-branchdefault.json"
# https://www.pulumi.com/registry/packages/github/api-docs/repositorytopics/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/repositoryTopics:RepositoryTopics\",\"name\": (\"repositoryTopics-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-repotopics.json"
# https://www.pulumi.com/registry/packages/github/api-docs/repositorycollaborators/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/repositoryCollaborators:RepositoryCollaborators\",\"name\": (\"repositoryCollaborators-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-repocollaborators.json"
# https://www.pulumi.com/registry/packages/github/api-docs/repositorydependabotsecurityupdates/
gh api --paginate "orgs/${ORG}/repos" -q ".[] | {\"type\":\"github:index/repositoryDependabotSecurityUpdates:RepositoryDependabotSecurityUpdates\",\"name\": (\"repositoryDependabotSecurityUpdates-\" + .name), \"id\": .name}" >"${TEMP_DIR}/gh-repodependabotsecurityupdates.json"
# https://www.pulumi.com/registry/packages/github/api-docs/teamrepository/
gh api graphql --paginate -f query="
  query (\$endCursor: String) {
    organization(login: \"${ORG}\") {
      teams(first: 100, after: \$endCursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          databaseId
	  slug
          repositories {
            nodes {
              name
            }
          }
        }
      }
    }
  }" -q '.data.organization.teams.nodes[] | {"slug": .slug, "repo": .repositories.nodes[].name, "id": .databaseId | tostring } | { "type": "github:index/teamRepository:TeamRepository", "name": ("teamRepo-" + .slug + "-" + .repo), "id" : (.id + ":" + .repo) }' >"${TEMP_DIR}/gh-teamrepository.json"
# https://www.pulumi.com/registry/packages/github/api-docs/branchprotection/
gh api graphql --paginate -f query="
  query (\$endCursor: String, \$endCursorRules: String) {
    organization(login: \"${ORG}\") {
      repositories(first: 100, after: \$endCursor) {
        nodes {
          branchProtectionRules(first: 100, after: \$endCursorRules) {
            nodes {
	      databaseId
              pattern
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
          name
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }" -q '.data.organization.repositories.nodes[] | { "repo": .name, "protection": .branchProtectionRules.nodes[] } | { "type": "github:index/branchProtection:BranchProtection", "name": ("branchProtection-" + .repo + "-" + (.protection.databaseId | tostring)), "id": (.repo + ":" + .protection.pattern) }' >"${TEMP_DIR}/gh-branchprotection.json"

jq -s '{"resources": .}' "${TEMP_DIR}"/gh-* >"${PROJECT_DIR}/github-${ORG}.json"
pulumi import --cwd "${PROJECT_DIR}" --file "github-${ORG}.json" --logtostderr --generate-code --skip-preview --yes --out index.ts
