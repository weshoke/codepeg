codepeg: listlpeg based lexer, parser and AST manipulation
======================================================================
See the copyright information in the file named `COPYRIGHT`.


Dependencies
-----------

* listlpeg: https://github.com/mascarenhas/lpeg-list


Structure
--------

### codepeg.lexer
Turns code into a stream of tokens.  Comments are left in the token stream even though they 
represent ignored text.  The parser will ignore any comment tokens so there's no harm done by 
leaving them in.  Tokens have the following format:


	{
		[1] = <token value>
		token = <token name>,
		start_idx = <starting character index in code>,
		end_idx = <ending character index in code>,
	}
	
The code represented by the token can be extracted from the input code with the string.sub function:
	
	string.sub(code, token.start_idx, token.end_idx-1)
	
