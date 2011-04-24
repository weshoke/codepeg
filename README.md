codepeg: listlpeg based lexer, parser and AST manipulation
======================================================================
See the copyright information in the file named `COPYRIGHT`.


codepeg is as a generic lexing and parsing system that is agnostic to any particular language.  
Lexers and parsers for a specific language are generated by writing a specification file that describes 
at a minimum the language's Tokens and Rules but can also include its Comments.  The lexer exclusively uses 
the Token and Comment definitions while the parser also makes use of the Rules.

In addition, codepeg aims to provide accurate and pertinent diagnostic information during both 
lexing and parsing.  During the lexing process codepeg provides hooks to signal malformed tokens.  
During the parsing process, codepeg tracks the parser as it moves through the grammar rules such that when 
a parsing error occurs, all the basic information required to determine what the error is is available.

When parsing fails, all pertinent information is stored in Parser's `rulestack` field and can be queried through Parser or by directly inspecting the Rulestack itself.  Currently stored information includes:

1. Stack of rules representing the furthest traversed position by the Parser over the input list of tokens
2. A list of tokens the Parser attempted to match against just before failing
3. The last token matched along with its position in the token stream and the active rule when the token was matched




Dependencies
-----------

* listlpeg: https://github.com/mascarenhas/lpeg-list


Structure
--------

### codepeg.Lexer
Turns code into a stream of tokens.  Comments are left in the token stream even though they 
represent ignored text.  The parser will ignore any comment tokens so there's no harm done by 
leaving them in.  Tokens have the following format:


	{
		[1] = <token value>,
		token = <token name>,
		start_idx = <starting character index in code>,
		end_idx = <ending character index in code>,
	}
	
The code represented by the token can be extracted from the input code with the string.sub function:
	
	string.sub(code, token.start_idx, token.end_idx-1)
	

### codepeg.Parser
Turns a stream of tokens into an Abstract Syntax Tree (AST).  The parser applies a grammar of rules to 
the token stream to break them into a hierarchical representation with a single root rule.  The parser 
keeps track of what rules have been applied/tried throughout the parsing process so that precise diagnostic
can be made.  All rules that match are added to the AST even if they only contain a single rule. Rules have 
the following format:

	{
		rule = <rule name>,
		[1] = <Token or Rule>,
		...
		[n] = <Token or Rule>,
	}


### codepeg.Stack
Generic stack data structure

### codepeg.Tokenlist
A data structure for keeping track of tokens and their associated rules

### codepeg.Rulestack
A data structure for tracking Parser state.  It maintains information describing what Parser rules are currently active, what tokens have been attempted on the last token position reached by the parser, and information about the last token the Parser matched.  Rulestack is used by Parser internally and can be queried through Parser's accessor methods.

### codepeg.ast
General AST querying and manipulation functions.

### codepeg.specification.lua
An example specification file for the Lua scripting language.  The specification implements the Lua grammar and 
can be used in conjunction with codepeg.lexer and codepeg.parser to lex and parse Lua code


Specification Files
--------
Specification files are the heart of codepeg.  They describe the structure of a language to be lexed and parser.  The 
three basic definitions are:
	
#### Token(patt, name, [priority])
Create a Token from `patt` with name `name`. `priority` defaults to 0.  It can be any numeric 
argument including the special value MAX_PRIORITY.  In general, tokens should be ordered from largest to 
smallest in order to prevent the lexer from breaking up larger tokens into smaller ones inadvertently.  For 
example `>>` can easily be converted to `>` `>` if `>` precedes `>>` in priority. See the example Lua specification 
for how to handle this automatically for keywords and operators.

Note, `patt` should not have any `V` lpeg patterns in it.  Tokens should be solely composed of basic patterns 
and captures.  Tokens are not turned into a grammar by the lexer.


#### Rule(patt, name)
Create a Rule from `patt` with name `name`.  Rules describe sequences of tokens and as such should contain 
exclusively patterns made up of grammar rules constructed from the `V` lpeg pattern.  Rules can depend on 
other tules and tokens only.


#### Comment(patt, name)
Comments are like tokens except they have no priority since it's implied that they have the highest priority 
during the lexing process.
	

#### LexErr(patt, msg)
LexErr will raise an error during the lexing process if `patt` succeeds and an error with `msg` as its message will be thrown.

