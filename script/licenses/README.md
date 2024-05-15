# 3rd Party :tada: dependencies

This directory contains scripts and files for generating a `NOTICE.txt` file containing all licenses for the third-party dependencies that Crawler uses.

## Types of dependencies

- Ruby Gems from `Gemfile` and `Gemfile.lock`
- Misc. dependencies, like JRuby, Tika, etc. not managed by a package manager

## Generate NOTICE.txt

```bash
./script/licenses/generate_notice_txt.rb
```

---

# Full commands to use locally

A few environment variables are needed to run these scripts locally.

The generated files should not be committed to Git as the NOTICE.txt are generated automatically when building the package on CI and similarly the CSV dependency reports are triggered by the Release Manager when a new release candidate is built.

## Generate NOTICE.txt

    RAILS_ENV=production bundle exec ruby script/3rd_party/generate_notice_txt.rb --file ent-search-NOTICE.txt

## Generate dependency report

    RAILS_ENV=production bundle exec ruby script/3rd_party/generate_dependency_report.rb --csv ent-search-deps.csv