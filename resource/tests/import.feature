@test-cluster-2 @import
Feature: Import

Background:
  Given I set preference .citekeyFormat to [auth][year]
  And I set preference .jabrefGroups to false
  And I set preference .defaultDateParserLocale to en-GB
  And I set preference .preserveCaps to inner

@aux
Scenario: AUX scanner
  When I import 149 references from 'import/AUX scanner-pre.json'
  And I import 0 references from 'import/AUX scanner.aux'
  Then the library should match 'import/AUX scanner-post.json'

@i1
Scenario: Better BibTeX Import 2
  When I import 2 references from 'import/Better BibTeX.002.bib'
  Then the library without collections should match 'import/Better BibTeX.002.json'
  And the markdown citation for Torre2008 should be '\(Torre & Verducci, 2008\)'
  And the markdown bibliography for Torre2008 should be '[@Torre2008]: #Torre2008 "Torre, J., & Verducci, T. (2008).  _The Yankee Years_. Doubleday." <a name="Torre2008"></a>Torre, J., & Verducci, T. \(2008\). _The Yankee Years_.  Doubleday.'
  And the markdown citation for orre2008 should be ''
  And the markdown bibliography for orre2008 should be ''

@i2
Scenario: option to mantain the braces and special commands in titles or all fields #100
  When I set preference .rawImports to true
  And I import 1 reference from 'import/Better BibTeX.007.bib'
  Then the library should match 'import/Better BibTeX.007.raw.json'
  And a library export using 'Better BibTeX' should match 'import/Better BibTeX.007.roundtrip.bib'

@i3
Scenario Outline: Better BibTeX Import
  When I import <references> reference from 'import/<file>.bib'
  Then the library without collections should match 'import/<file>.json'

  Examples:
  | file                                                                        | references  |
  | Failure to handle unparsed author names (92)                                | 1           |
  | Better BibTeX.001                                                           | 1           |
  | Better BibTeX.003                                                           | 2           |
  | Better BibTeX.004                                                           | 1           |
  | Better BibTeX.005                                                           | 1           |
  | Better BibTeX.006                                                           | 1           |
  | Better BibTeX.007                                                           | 1           |
  | Better BibTeX.008                                                           | 1           |
  | Better BibTeX.009                                                           | 2           |
  | Better BibTeX.010                                                           | 1           |
  | Better BibTeX.011                                                           | 1           |
  | Better BibTeX.012                                                           | 1           |
  | Better BibTeX.013                                                           | 2           |
  | Better BibTeX.014                                                           | 1           |
  | Better BibTeX.015                                                           | 1           |
  | Literal names                                                               | 1           |
  | Author splitter failure                                                     | 1           |
  | Problem when importing BibTeX entries with square brackets #94              | 1           |
  | Problem when importing BibTeX entries with percent sign #95 or preamble #96 | 1           |
  | Import fails to perform @String substitutions #154                          | 1           |

#@97
#Scenario: Maintain the JabRef group and subgroup structure when importing a BibTeX db #97
#  When I import 915 reference with 42 attachments from 'import/Maintain the JabRef group and subgroup structure when importing a BibTeX db #97.bib'
#  Then the library should match 'import/Maintain the JabRef group and subgroup structure when importing a BibTeX db #97.json'

