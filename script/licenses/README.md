# 3rd Party :tada: dependencies

This directory contains scripts and files for generating a `NOTICE.txt` file containing all licenses for the third-party dependencies that Crawler uses.
It will look at the SPDX license for Ruby gems.
If this cannot be found, it will attempt to download the LICENSE file and add it to the project for future reference.
When a LICENSE file doesn't exist (or is in an unexpected location or format), a manual override must be added.

Downloaded license files are added to the directories `rubygems_licenses` or `misc_licneses`.

All license texts are then added to the repository's [NOTICE.txt](../../NOTICE.txt) file.

## Types of dependencies

- Ruby Gems from `Gemfile` and `Gemfile.lock`
- Misc. dependencies, like JRuby, Tika, etc. not managed by a package manager

## Generate NOTICE.txt

```bash
./script/licenses/generate_notice_txt.rb
```
