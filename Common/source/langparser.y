
/******************************************************************************

    UserLand Frontier(tm) -- High performance Web content management,
    object database, system-level and Internet scripting environment,
    including source code editing and debugging.

    Copyright (C) 1992-2004 UserLand Software, Inc.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

******************************************************************************/

  
%{

/*
langparser.y generates langparser.c.  

use MPW Shell and the MPW tool MacYACC to create a LSC-compatible parser 
in langparser.c. the command line to generate langparser.c and yytab.h is:

	macyacc -d  "langparser.y"

*/

/*
these declarations make it possible to compile and run langparser.c 
with no modification to the source code as generated by MacYACC.

5/29/92 dmb: added try statement handling

5.1.2 dmb: added cleanandexit block to dispose everything on memory errors
*/

#ifdef MACVERSION
#include <standard.h>
#endif

#ifdef WIN95VERSION
#include "standard.h"
#endif

#include "memory.h"
#include "strings.h"
#include "lang.h"
#include "langinternal.h"
#include "langparser.h"
#include <stdio.h>
#include <string.h>


static FILE __file[1];

static int fprintf (FILE *f, const char *s, ...) {return (0);}

static FILE *fopen (const char *s1, const char *s2) {return (NULL);}

static int fclose (FILE *f) {return (0);}

static int strcmp (const char * str1, const char * str2) {return (0);}

/*
10/2/91 dmb: a disturbing discovery -- our error handling doesn't deallocate 
any of the code tree that's been built so for.  searching through langparser.c, 
it appears that there are three data structures will need to go through: yyval, 
yylval, and the value stack, yyv.  Unfortunately, the value stack pointer, yypv, 
is a local in yyparse, so we have to be tricky to get at it.  so I'm replacing 
the yyerror routine with a macro that calls the real error routine, but passes 
the stack pointer as an additional parameter.

there's probably a much cleaner way to do this, but I don't have the 
documentation, nor much time...

11/22/91 dmb: well, there's little time indeed, but we now have MacYACC 3.0, and 
a little documentation.  The right was to deal with data structure disposal on 
errors is to make sure that there are reduction rules for every error situation, 
so that after yyerror is called the parser can ruduce the stack all the way down 
to our start token (module), where the tree can be safely disposed.  I've added a 
number of such reductions that should cover many error situations, but a much more 
thorough job needs to be done eventually.  It's hard to trap errors at a very atomic 
level without introducing ambiguities to the grammer (i.e. reduction conflicts).  
So, given the time to work on it, I would go through the definition of "statement" 
and add rules for every permutation of errors within the more complex contructs.  The 
key thing to understand is that "expr" is written to handle any error, so anything 
that depends on expr is covered.  It's unique contructs associated with some compound 
statements that need extra work.
*/

%}

%token EQtoken 400 /*must agree with numbers in langtokens.h*/

%token NEtoken 401

%token GTtoken 402

%token LTtoken 403

%token GEtoken 404

%token LEtoken 405

%token nottoken 406

%token andandtoken 407 

%token orortoken 408

%token beginswithtoken 409

%token endswithtoken 410

%token containstoken 411

%token bitandtoken 412

%token bitortoken 413

%token looptoken 500 /*must agree with numbers in langtokens.h*/

%token filelooptoken 501

%token intoken 502

%token breaktoken 503

%token returntoken 504

%token iftoken 505

%token thentoken 506

%token elsetoken 507

%token bundletoken 508

%token localtoken 509

%token ontoken 510
	
%token whiletoken 511

%token casetoken 512

%token kerneltoken 513

%token fortoken 514

%token totoken 515

%token downtotoken 516

%token continuetoken 517

%token withtoken 518

%token trytoken 519

%token globaltoken 520

%token errortoken

%token eoltoken

%token constanttoken

%token identifiertoken 

%token othertoken

%token assigntoken

%token addtoken 

%token subtracttoken 

%token multiplytoken 

%token dividetoken

%token modtoken

%token plusplustoken 

%token minusminustoken


%left ','

%left assigntoken

%left orortoken

%left andandtoken

%left EQtoken NEtoken

%left LTtoken GTtoken LEtoken GEtoken beginswithtoken endswithtoken containstoken

%left addtoken subtracttoken

%left multiplytoken dividetoken modtoken

%right nottoken

%right plusplustoken minusminustoken unaryminus '@'

%left '^'

%left '.'

%start module /*this is our goal*/

%%



module:
	
	statementlist eoltoken {
		
		yytrace ("module | statementlist eoltoken");
		
		if (pcyyerrct) {
			
			$$ = $1;
			
			return (1);
			}
		
		if (!pushbinaryoperation (moduleop, $1, nil, &$$))
			goto cleanexit;
		
		return (0);
	
 	cleanexit:
	    while (--yypv - &yyv[0] > 0)
			langdisposetree (*yypv);
	
		return (2);
		}
	
	| error {
		
		yytrace ("module | error");
		
		return (1);
		}
	;

bracketedidentifier:
	
	identifiertoken {
		
		yytrace ("bracketedidentifier : identifiertoken");
		
		$$ = $1;
		}
	
	| '[' expr ']' {
		
		yytrace ("bracketedidentifier | '[' expr ']'");
		
		if (!pushunaryoperation (bracketop, $2, &$$))
			goto cleanexit;
		}
	;

handlerheader:
	
	ontoken bracketedidentifier '(' namelist ')' {
		
		yytrace ("handlerheader | ontoken bracketedidentifier '(' namelist ')'");
		
		if (!pushbinaryoperation (procop, $2, $4, &$$))
			goto cleanexit;
		}
	
	| ontoken bracketedidentifier '(' ')' {
		
		yytrace ("handlerheader | ontoken bracketedidentifier '(' ')'");
		
		if (!pushbinaryoperation (procop, $2, nil, &$$))
			goto cleanexit;
		}
	
	/*
	| ontoken error {
		
		$$ = nil;
		}
	*/
	;

optionalinit:
	
	/*emptiness*/ {
		
		yytrace ("optionalinit | empty");
		
		$$ = nil;
		}
	
	| assigntoken expr {
		
		yytrace ("optionalinit | assigntoken expr");
		
		$$ = $2;
		}
	
	| error {
		
		yytrace ("optionalinit | error");
		
		$$ = nil;
		}
	;

namelistid:
	
	bracketedidentifier optionalinit {
		
		yytrace ("namelistid | optionalinit");
		
		if ($2 == nil)
			$$ = $1; /*just return the id*/
			
		else {
			if (!pushbinaryoperation (assignlocalop, $1, $2, &$$))
				goto cleanexit;
			}
		}
	
	| error {
		
		yytrace ("namelistid | error");
		
		$$ = nil;
		}
	;

namelist:
	
	namelistid {
		
		yytrace ("namelist | namelistid");
		
		$$ = $1; /*start the name list off with our address*/
		}
	
	| namelist ',' namelistid {
		
		yytrace ("namelist | namelist ',' namelistid");
		
		if (!pushlastlink ($3, $1)) /*add new name to end of list*/
			goto cleanexit;
		}
	
	| namelist ';' namelistid {
		
		yytrace ("namelist | namelist ';' namelistid");
		
		if (!pushlastlink ($3, $1)) /*add new name to end of list*/
			goto cleanexit;
		}
	;

statementlist: 
	
	statement {
		
		yytrace ("statementlist: statement");
		
		$$ = $1; /*start the statement list off with our address*/
		}
	
	| statementlist ';' statement {
		
		yytrace ("statementlist | statementlist ';' statement");
		
		if (!pushlastlink ($3, $1)) /*add new statement to end of list*/
			goto cleanexit;
		
		$$ = $1; 
		}
	;

bracketedstatementlist:
	
	'{' statementlist '}' {
		
		yytrace ("bracketedstatementlist: '{' statementlist '}'");
		
		$$ = $2;
		}
	
	| error {
		
		yytrace ("bracketedstatementlist | error");
		
		$$ = nil;
		}
	;

derefid:
	
	term '^' {
		
		yytrace ("derefid : term '^'");
		
		if (!pushunaryoperation (dereferenceop, $1, &$$))
			goto cleanexit;
		}
	
	| functionref '^' {
		
		yytrace ("derefid | functionref '^'");
		
		if (!pushunaryoperation (dereferenceop, $1, &$$))
			goto cleanexit;
		}
	
	| '(' expr ')'  '^' {
		
		yytrace ("derefid | '(' expr ')' '^'");
		
		if (!pushunaryoperation (dereferenceop, $2, &$$))
			goto cleanexit;
		}
	;

dottedid:
	
	term '.' bracketedidentifier {
		
		yytrace ("dottedid : term '.' bracketedidentifier");
		
		if (!pushbinaryoperation (dotop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| term '.' error {
		
		yytrace ("dottedid : term '.' error");
		
		$$ = $1;
		}
	;

rangeref:
	
	expr totoken expr {
		
		yytrace ("rangeref: expr totoken expr");
		
		if (!pushbinaryoperation (rangeop, $1, $3, &$$))
			goto cleanexit;
		}
	;

arrayref:
	
	term '[' expr ']' {
		
		yytrace ("arrayref: term '[' expr ']'");
		
		if (!pushbinaryoperation (arrayop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| term '[' rangeref ']' {
		
		yytrace ("arrayref | term '[' rangeref ']'");
		
		if (!pushbinaryoperation (arrayop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| term '[' fieldspec ']' {
		
		yytrace ("arrayref | term '[' fieldspec ']'");
		
		if (!pushbinaryoperation (arrayop, $1, $3, &$$))
			goto cleanexit;
		}
	;

term:
	
	dottedid {
		
		yytrace ("term: dottedid");
		
		$$ = $1;
		}
	
	| arrayref {
		
		yytrace ("term | arrayref");
		
		$$ = $1;
		}
	
	| bracketedidentifier {
		
		yytrace ("term | bracketedidentifier");
		
		$$ = $1;
		}
	
	| derefid {
		
		yytrace ("term | derefid");
		
		$$ = $1;
		}
	;

statement:
	
	/*emptiness*/ {
		
		yytrace ("statement: <empty statement>");
		
		if (!pushoperation (noop, &$$)) /*a place for the debugger to stop*/
			goto cleanexit;
		}
	
	| expr {
		
		yytrace ("statement: expr");
		
		$$ = $1;
		}
	
	| term assigntoken expr {
		
		yytrace ("statement | term assigntoken expr");
		
		if (!pushbinaryoperation (assignop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| handlerheader bracketedstatementlist {
		
		yytrace ("statement : handlerheader bracketedstatementlist");
		
		if (!pushbinaryoperation (moduleop, $2, $1, &$$))
			goto cleanexit;		
		}
	
	| handlerheader '{' kernelcall '}' {
		
		yytrace ("statement : handlerheader '{' kernelcall '}'");
		
		if (!pushbinaryoperation (moduleop, $3, $1, &$$))
			goto cleanexit;		
		}
	
	| localtoken '(' namelist ')' {
		
		yytrace ("statement | localtoken '(' namelist ')'");
		
		if (!pushunaryoperation (localop, $3, &$$))
			goto cleanexit;
		}
	
	| localtoken '{' namelist '}' {
		
		yytrace ("statement | localtoken '{' namelist '}'");
		
		if (!pushunaryoperation (localop, $3, &$$))
			goto cleanexit;
		}
	
	| globaltoken '(' namelist ')' {
		
		yytrace ("statement | globaltoken '(' namelist ')'");
		
		if (!pushunaryoperation (globalop, $3, &$$))
			goto cleanexit;
		}
	
	| globaltoken '{' namelist '}' {
		
		yytrace ("statement | globaltoken '{' namelist '}'");
		
		if (!pushunaryoperation (globalop, $3, &$$))
			goto cleanexit;
		}
	
	| fileloopheader bracketedstatementlist {
		
		yytrace ("statement | fileloopheader bracketedstatementlist");
		
		if (!pushtripletstatementlists (nil, $2, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| loopheader bracketedstatementlist {
		
		yytrace ("statement | loopheader bracketedstatementlist");
		
		if (!pushloopbody ($2, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| forloopheader bracketedstatementlist {
		
		yytrace ("statement | forloopheader bracketedstatementlist");
		
		if (!pushloopbody ($2, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| forinloopheader bracketedstatementlist {
		
		yytrace ("statement | forinloopheader bracketedstatementlist");
		
		if (!pushloopbody ($2, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| ifheader bracketedstatementlist {
		
		yytrace ("statement | ifheader bracketedstatementlist");
		
		if (!pushtripletstatementlists ($2, nil, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| ifheader bracketedstatementlist elsetoken bracketedstatementlist {
		
		yytrace ("statement | ifheader bracketedstatementlist elsetoken bracketedstatementlist");
		
		if (!pushtripletstatementlists ($2, $4, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| bundleheader bracketedstatementlist {
		
		yytrace ("statement | bundleheader bracketedstatementlist");
		
		if (!pushunarystatementlist ($2, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| breaktoken '(' ')' {
		
		yytrace ("statement | breaktoken '(' ')'");
		
		if (!pushoperation (breakop, &$$))
			goto cleanexit;
		}
	
	| breaktoken {
		
		yytrace ("statement | breaktoken");
		
		if (!pushoperation (breakop, &$$))
			goto cleanexit;
		}
	
	| continuetoken {
		
		yytrace ("statement | continuetoken");
		
		if (!pushoperation (continueop, &$$))
			goto cleanexit;
		}
	
	| returntoken optionalexpr {
		
		yytrace ("statement | returntoken");
		
		if (!pushunaryoperation (returnop, $2, &$$))
			goto cleanexit;
		}
	
	| caseheader '{' casebody '}' {
		
		yytrace ("statement | caseheader casebody");
		
		if (!pushtripletstatementlists ($3, nil, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| caseheader '{' casebody '}' elsetoken bracketedstatementlist {
		
		yytrace ("statement | caseheader casebody elsetoken bracketedstatementlist");
		
		if (!pushtripletstatementlists ($3, $6, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| withheader bracketedstatementlist {
		
		yytrace ("statement | withheader bracketedstatementlist");
		
		if (!pushtripletstatementlists ($2, nil, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| tryheader bracketedstatementlist {
		
		yytrace ("statement | tryheader bracketedstatementlist");
		
		if (!pushtripletstatementlists ($2, nil, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| tryheader bracketedstatementlist elsetoken bracketedstatementlist {
		
		yytrace ("statement | tryheader bracketedstatementlist elsetoken bracketedstatementlist");
		
		if (!pushtripletstatementlists ($2, $4, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	
	| expr error {
		
		yytrace ("statement | expr error");
		
		$$ = $1;
		}
	
	/*
	| expr error expr {
		
		if (!pushbinaryoperation (noop, $1, $3, &$$))
			goto cleanexit;
		}
	*/
	;

kernelcall:
	
	kerneltoken '(' dottedid ')' {
		
		yytrace ("kernelcall: kerneltoken '(' dottedid ')'");
		
		if (!pushkernelcall ($3, &$$))
			return (1);
		}
	;

/*
fileloopspec:
	
	expr {
		
		yytrace ("fileloopspec: expr");
		
		$$ = $1;
		}
	
	| constanttoken '[' expr ']' {
		
		yytrace ("fileloopspec | constanttoken '[' expr ']'");
		
		if (!pushbinaryoperation (arrayop, $1, $3, &$$))
			goto cleanexit;
		}
	;
*/

fileloopheader:
	
	filelooptoken '(' bracketedidentifier intoken expr ')' {
		
		yytrace ("fileloopheader: filelooptoken '(' bracketedidentifier intoken expr ')'");
		
		if (!pushquadruplet (fileloopop, $3, $5, nil, nil, &$$))
			goto cleanexit;
		}
	
	| filelooptoken '(' bracketedidentifier intoken expr ',' expr ')' {
		
		yytrace ("fileloopheader | filelooptoken '(' bracketedidentifier intoken expr ',' expr ')'");
		
		if (!pushquadruplet (fileloopop, $3, $5, nil, $7, &$$))
			goto cleanexit;
		}
	
	| filelooptoken '(' bracketedidentifier error {
		
		yytrace ("fileloopheader | filelooptoken '(' bracketedidentifier error");
		
		if (!pushquadruplet (fileloopop, $3, nil, nil, nil, &$$))
			goto cleanexit;
		}
	;

loopheader:
	
	looptoken '(' statement ';' expr ';' statement ')' {
		
		yytrace ("loopheader: looptoken '(' statement ';' expr ';' statement ')'");
		
		if (!pushloop ($3, $5, $7, &$$))
			goto cleanexit;
		}
	
	| looptoken {
		
		yytrace ("loopheader | looptoken");
		
		if (!pushloop (nil, nil, nil, &$$))
			goto cleanexit;
		}
	
	| looptoken '(' expr ')' {
		
		yytrace ("loopheader | looptoken '(' expr ')'");
		
		if (!pushloop ($3, nil, nil, &$$))
			goto cleanexit;
		}
	
	| whiletoken expr {
		
		yytrace ("loopheader | whiletoken expr");
		
		if (!pushloop (nil, $2, nil, &$$))
			goto cleanexit;
		}
	
	| looptoken '(' statement ';' expr ')' {
		
		yytrace ("loopheader | looptoken '(' statement ';' expr ')'");
		
		if (!pushloop ($3, $5, nil, &$$))
			goto cleanexit;
		}
	;

forloopheader:
	
	fortoken term assigntoken expr totoken expr {
		
		yytrace ("forloopheader: fortoken term assigntoken expr totoken expr");
		
		if (!pushquadruplet (forloopop, $4, $6, $2, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken '(' term assigntoken expr totoken expr ')' {
		
		yytrace ("forloopheader | fortoken '(' term assigntoken expr totoken expr ')' ");
		
		if (!pushquadruplet (forloopop, $5, $7, $3, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken term assigntoken expr downtotoken expr {
		
		yytrace ("forloopheader | fortoken term assigntoken expr downtotoken expr");
		
		if (!pushquadruplet (fordownloopop, $4, $6, $2, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken '(' term assigntoken expr downtotoken expr ')' {
		
		yytrace ("forloopheader | fortoken '(' term assigntoken expr downtotoken expr ')' ");
		
		if (!pushquadruplet (fordownloopop, $5, $7, $3, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken term assigntoken expr error {
		
		yytrace ("forloopheader: fortoken term assigntoken expr error");
		
		if (!pushquadruplet (noop, $2, $4, nil, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken term error {
		
		yytrace ("forloopheader: fortoken term error");
		
		if (!pushquadruplet (noop, $2, nil, nil, nil, &$$))
			goto cleanexit;
		}
	;

forinloopheader:
	
	fortoken term intoken expr {
		
		yytrace ("forinloopheader: fortoken term intoken expr");
		
		if (!pushquadruplet (forinloopop, $4, $2, nil, nil, &$$))
			goto cleanexit;
		}
	
	| fortoken '(' term intoken expr ')' {
		
		yytrace ("forinloopheader | fortoken '(' term intoken expr ')' ");
		
		if (!pushquadruplet (forinloopop, $5, $3, nil, nil, &$$))
			goto cleanexit;
		}
	;

ifheader:
	
	iftoken expr {
		
		yytrace ("ifheader: iftoken expr");
		
		if (!pushtriplet (ifop, $2, nil, nil, &$$))
			goto cleanexit;
		}
	;

tryheader:
	
	trytoken {
		
		yytrace ("tryheader | trytoken");
		
		if (!pushtriplet (tryop, nil, nil, nil, &$$)) /*it's really just a binary*/
			goto cleanexit;
		}
	;

bundleheader:
	
	bundletoken {
		
		yytrace ("bundleheader: bundletoken");
		
		if (!pushunaryoperation (bundleop, nil, &$$))
			goto cleanexit;
		}
	;

caseheader:
	
	casetoken expr {
		
		yytrace ("caseheader | casetoken expr");
		
		if (!pushtriplet (caseop, $2, nil, nil, &$$))
			goto cleanexit;
		}
	;

optionalstatementlist:
	
	/*emptiness*/ {
	
		yytrace ("optionalstatementlist : (empty list)");
		
		$$ = nil;
		}
	
	| bracketedstatementlist {
		
		yytrace ("optionalstatementlist | bracketedstatementlist");
		
		$$ = $1;
		}
	;

casebody:
	
	expr optionalstatementlist {
		
		yytrace ("casebody: expr optionalstatementlist");
		
		if (!pushbinaryoperation (casebodyop, $1, $2, &$$))
			goto cleanexit;
		}
	
	| casebody ';' expr optionalstatementlist {
		
		yytrace ("casebody | casebody ';' expr optionalstatementlist");
		
		if (!pushbinaryoperation (casebodyop, $3, $4, &$$))
			goto cleanexit;
		
		if (!pushlastlink ($$, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	;

withheader:
	
	withtoken termlist {
		
		yytrace ("withheader: withtoken termlist");
		
		if (!pushbinaryoperation (withop, $2, nil, &$$))
			goto cleanexit;
		}
	;

termlist: 
	
	term {
		
		yytrace ("termlist: term");
		
		$$ = $1;
		}
	
	| termlist ',' term {
		
		yytrace ("termlist | termlist ',' term");
		
		if (!pushlastlink ($3, $1))
			goto cleanexit;
			
		$$ = $1;
		}
	;

exprlist: 
	
	expr {
		
		yytrace ("exprlist: expr");
		
		$$ = $1;
		}
	
	| exprlist ',' expr {
		
		yytrace ("exprlist | exprlist ',' expr");
		
		if (!pushlastlink ($3, $1))
			goto cleanexit;
			
		$$ = $1;
		}
	;


optionalexprlist:
	
	/*emptiness*/ {
	
		yytrace ("optionalexprlist : (empty list)");
		
		$$ = nil;
		}
	
	| exprlist {
		
		yytrace ("optionalexprlist | exprlist");
		
		$$ = $1;
		}
	;

/*for optional parameters

optionalexprlist:
	
	optionalexpr {
		
		yytrace ("optionalexprlist: optionalexpr");
		
		$$ = $1;
		}
	
	| optionalexprlist ',' optionalexpr {
		
		yytrace ("optionalexprlist | optionalexprlist ',' optionalexpr");
		
		if (!pushlastoptionallink ($3, $1, &$$))
			goto cleanexit;
		}
	;

*/

optionalexpr:
	
	/*emptiness*/ {
		
		yytrace ("optionalexpr : (empty expr)");
		
		$$ = nil;
		}
	
	| expr {
		
		yytrace ("optionalexpr | expr");
		
		$$ = $1;
		}
	;


fieldspec:
	
	expr ':' expr {
		
		yytrace ("fieldspec: expr : expr ");
		
		if (!pushbinaryoperation (fieldop, $1, $3, &$$))
			goto cleanexit;
		}
	;

fieldlist:
	
	fieldspec {
		
		yytrace ("fieldlist: fieldspec ");
		
		$$ = $1;
		}
	
	| fieldlist ',' fieldspec {
		
		yytrace ("fieldlist | fieldlist ',' fieldspec");
		
		if (!pushlastlink ($3, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	;

namedvalue:
	
	bracketedidentifier ':' expr {
		
		yytrace ("namedvalue: bracketedidentifier : expr ");
		
		if (!pushbinaryoperation (fieldop, $1, $3, &$$))
			goto cleanexit;
		}
	;

namedvaluelist:
	
	namedvalue {
		
		yytrace ("namedvaluelist: namedvalue ");
		
		$$ = $1;
		}
	
	| namedvaluelist ',' namedvalue {
		
		yytrace ("namedvaluelist | namedvaluelist ',' namedvalue");
		
		if (!pushlastlink ($3, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	;

parameterlist:
	
	optionalexprlist {
		
		yytrace ("parameterlist : optionalexprlist");
		
		$$ = $1;
		}
	
	| namedvaluelist {
		
		yytrace ("parameterlist | namedvaluelist");
		
		$$ = $1;
		}
	
	| exprlist ',' namedvaluelist {
		
		yytrace ("parameterlist | exprlist ',' namedvaluelist");
		
		if (!pushlastlink ($3, $1))
			goto cleanexit;
		
		$$ = $1;
		}
	;


functionref:
	
	term '(' parameterlist ')' {
		
		yytrace ("functionref: term '(' parameterlist ')'");
		
		if (!pushfunctioncall ($1, $3, &$$))
			goto cleanexit;
		}
	;

expr:
	constanttoken {
		
		yytrace ("expr | constanttoken");
		
		$$ = $1;
		}
	
	| term {
		
		yytrace ("expr | term");
		
		$$ = $1;
		}
	
	| '@' term {
		
		yytrace ("expr | '@' term");
		
		if (!pushunaryoperation (addressofop, $2, &$$))
			goto cleanexit;
		}
	
	| functionref {
		
		yytrace ("expr | functionref");
		
		$$ = $1;
		}
	
	| plusplustoken term {
		
		yytrace ("expr | plusplustoken term"); 
		
		if (!pushunaryoperation (incrpreop, $2, &$$))
			goto cleanexit;
		}
	
	| term plusplustoken {
		
		yytrace ("expr | term plusplustoken");
		
		if (!pushunaryoperation (incrpostop, $1, &$$))
			goto cleanexit;
		}
	
	| minusminustoken term {
		
		yytrace ("expr | minusminustoken term");
		
		if (!pushunaryoperation (decrpreop, $2, &$$))
			goto cleanexit;
		}
	
	| term minusminustoken {
		
		yytrace ("expr | term minusminustoken");
		
		if (!pushunaryoperation (decrpostop, $1, &$$))
			goto cleanexit;
		}
	
	| '(' expr ')' {
		
		yytrace ("expr | '(' expr ')'");
		
		$$ = $2;
		}
	
	| expr addtoken expr {
		
		yytrace ("expr | expr addtoken expr");
		
		if (!pushbinaryoperation (addop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr subtracttoken expr {
		
		yytrace ("expr | expr subtracttoken expr");
		
		if (!pushbinaryoperation (subtractop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr multiplytoken expr {
		
		yytrace ("expr | expr multiplytoken expr");
		
		if (!pushbinaryoperation (multiplyop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr dividetoken expr {
		
		yytrace ("expr | expr dividetoken expr");
		
		if (!pushbinaryoperation (divideop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr modtoken expr {
		
		yytrace ("expr | expr modtoken expr");
		
		if (!pushbinaryoperation (modop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr EQtoken expr {
		
		yytrace ("expr | expr EQtoken expr");
		
		if (!pushbinaryoperation (EQop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr NEtoken expr {
		
		yytrace ("expr | expr NEtoken expr");
		
		if (!pushbinaryoperation (NEop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr LTtoken expr {
		
		yytrace ("expr | expr LTtoken expr");
		
		if (!pushbinaryoperation (LTop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr LEtoken expr {
		
		yytrace ("expr | expr LEtoken expr");
		
		if (!pushbinaryoperation (LEop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr GTtoken expr {
		
		yytrace ("expr | expr GTtoken expr");
		
		if (!pushbinaryoperation (GTop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr GEtoken expr {
		
		yytrace ("expr | expr GEtoken expr");
		
		if (!pushbinaryoperation (GEop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr beginswithtoken expr {
		
		yytrace ("expr | expr beginswithtoken expr");
		
		if (!pushbinaryoperation (beginswithop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr endswithtoken expr {
		
		yytrace ("expr | expr endswithtoken expr");
		
		if (!pushbinaryoperation (endswithop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr containstoken expr {
		
		yytrace ("expr | expr containstoken expr");
		
		if (!pushbinaryoperation (containsop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr orortoken expr {
		
		yytrace ("expr | expr orortoken expr");
		
		if (!pushbinaryoperation (ororop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| expr andandtoken expr {
		
		yytrace ("expr | expr andandtoken expr");
		
		if (!pushbinaryoperation (andandop, $1, $3, &$$))
			goto cleanexit;
		}
	
	| subtracttoken expr %prec unaryminus {
		
		yytrace ("expr | subtracttoken expr %prec unaryminus");
		
		if (!pushunaryoperation (unaryop, $2, &$$))
			goto cleanexit;
		}
	
	| nottoken expr {
		
		yytrace ("expr | nottoken expr");
		
		if (!pushunaryoperation (notop, $2, &$$))
			goto cleanexit;
		}
	
	| '{' optionalexprlist '}' {
		
		yytrace ("expr | '{' exprlist '}'");
		
		if (!pushunaryoperation (listop, $2, &$$))
			goto cleanexit;
		}
	
	| '{' fieldlist '}' {
		
		yytrace ("expr | '{' fieldlist '}'");
		
		if (!pushunaryoperation (recordop, $2, &$$))
			goto cleanexit;
		}
	
	/*
	| error {
		
		yytrace ("expr | error");
		
		$$ = $1;
		}
	*/
	;

%%

#ifdef fldebug

	static void yytrace (char * s) {
		
		bigstring bs;
		
		copyctopstring (s, bs);
		
		langtrace (bs);
		} /*yytrace*/

#else

	#define yytrace(s)

#endif


static int yylex (void) {
	
	/*
	get the next token from the input stream.  return the token number, and
	set the global yylval to the value of the token, if it has one.
	*/
	
	return (parsegettoken (&yylval));
	} /*yylex*/


static void yyerror (char *s) {
	
	/*
	langdisposetree (yyval);
	
	langdisposetree (yylval);
	*/
	
	/*
	clearbytes (&parseresult, (long) sizeof (parseresult));
	*/
	
	parseerror ((ptrstring) s); 
	} /*yyerror*/




