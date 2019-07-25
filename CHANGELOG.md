## CHANGELOG for Xmlfile

#### unreleased

- Convert module to VoxPupuli module
- Move dummy lens provider code to Puppet_X utility namespace
- Adds more tests for set and rm lens functions
- Fixes regex issue when selecting with multiple attributes

#### v0.4.0

- Fixes issues introduced by deprecation of :parent and type inheritance.

#### v0.3.1

- Regular expressions tweaked for 1.8.7 compatibility.

#### v0.3.0

- Augeas add command equivalent added.
- Aliases for ins and rm(insert and remove, respectively) created so it functions more like the augeas type.
- Sort behavior fixed so that matching for child node name sorting is triggered on both null and 0-length string args.
- Conditional behavior for numerals improved. If both parts of evaluate are pure digits, does a to_i on both before comparison.
- Raw processing now on by default.
- Updated this document.

#### v0.2.0

- Automatic importation of docs for inherited attributes.
