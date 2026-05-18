ruleset {
    description 'CodeNarc rules for the rules_groovy example.'

    ruleset('rulesets/basic.xml')
    ruleset('rulesets/imports.xml')
    ruleset('rulesets/naming.xml')
    ruleset('rulesets/unused.xml')
}
