extends Node
## Version — the build's version string, in one place.
##
## Semantic versioning, MAJOR.MINOR.PATCH:
##
##   MAJOR  a break in save compatibility or in the shape of the run itself.
##   MINOR  a feature milestone — a build that ships new surfaces or systems.
##   PATCH  bug fixes and tuning against an unchanged feature set.
##
## The number lives HERE and nowhere else. The title screen reads it, the web
## export stamps it into the HTML shell's <title>, and the parity suite asserts
## it is well-formed. A version written down twice is a version that disagrees
## with itself the first time somebody bumps one copy, so nothing else declares
## a literal — `Version.VERSION` is the only source.
##
## Registered as an autoload so a screen can reach it by path (`/root/Version`)
## the same way it reaches GameState, without preloading a script for a string.

const VERSION := "0.1.2"

## The pieces, for anything that needs to compare rather than display.
func major() -> int:
	return int(VERSION.split(".")[0])

func minor() -> int:
	return int(VERSION.split(".")[1])

func patch() -> int:
	return int(VERSION.split(".")[2])

## What the title screen shows. Kept here rather than formatted at the call site
## so every surface that stamps the build stamps it identically.
func display() -> String:
	return "v%s" % VERSION
