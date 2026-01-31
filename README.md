# github-workflows-monitor

A Bash script which collects data on GitHub actions run across a given list of repositories, in a given date range.
It writes the report in an output csv file.

It reads configuration from `.env` file:
* `GH_TOKEN` - GitHub token
* `REPOS` - list of repositories (in format org/repo_name)
* `FETCH_RANGE` - date or a date range for which report needs to be made. If omitted, a current date is used.
  * If `FETCH_RANGE=YYYY-MM-DD`, csv file will be named in format: `workflows_YYYY-MM-DD.csv`.
  * If `FETCH_RANGE=YYYY-MM-DD..YYYY-MM-DD`, csv file will be named in format: `workflows_YYYY-MM-DD_to_YYYY-MM-DD.csv`.

If the file with the same name already exists, it will be overwritten.

This csv file can then be imported to Google Spreadsheet.

## Prerequisites

In GitHub settings, make sure you have a valid GitHub Personal (Classic) token which has the following permissions:
* repo
* workflow
* read:org

To verify it:

```
gh api user -i | grep -E "x-ratelimit-remaining|HTTP/"
```

If it's valid, the output is:
```
HTTP/2.0 200 OK
```

If it's not valid (e.g. it's expired):
```
HTTP/2.0 401 Unauthorized
gh: Bad credentials (HTTP 401)
```

## Configuration

To get a list of all repositories in an organization use:

```
gh repo list -L 200 <org_name> | awk '{print $1}'
```

`-L <number>` - list only first `<number>` repositories.


 They are ordered by recent activity (last updated) by default.


## Execution

Before running the script, make sure it is executable:
```
chmod +x ./main.sh
```

To create a report for workflows run today, simply run:
```
./main.sh
```
