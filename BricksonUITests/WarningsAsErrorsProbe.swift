// Temporary: deliberate warnings, so CI shows that a warning in this test
// target fails the build, and that SWIFT_WARNINGS_AS_WARNINGS_GROUPS keeps
// the one group it names a warning (docs/DECISIONS.md, "Warnings are
// errors"). A later commit in the same pull request deletes this file.

@available(*, deprecated, message: "Probe only.")
func deprecatedProbe() -> Int { 1 }

func warningsAsErrorsProbe() -> Int {
    let unusedProbe = 1 // [#NoUsage]: kept a warning by project.yml
    return deprecatedProbe() // [#DeprecatedDeclaration]: must be an error
}
