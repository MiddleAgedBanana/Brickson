// Temporary: a warning on purpose, so CI shows that a warning in the app
// now fails the build (docs/DECISIONS.md, "Warnings are errors"). A later
// commit in the same pull request deletes this file.
func warningsAsErrorsProbe() {
    let unusedProbe = 1
}
