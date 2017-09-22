#----------------------------------------------------------------------------
# vbfilter.awk - doxygen VB .NET filter script - v2.4.1
#
# Creation:     26.05.2010  Vsevolod Kukol
# Last Update:  09.10.2011  Vsevolod Kukol
#
# Copyright (c) 2010-2011 Vsevolod Kukol, sevo(at)sevo(dot)org
#
# Inspired by the Visual Basic convertion script written by
# Mathias Henze. Rewritten from scratch with VB.NET support by
# Vsevolod Kukol.
#
# requirements: doxygen, gawk
#
# usage:
#    1. create a wrapper shell script:
#        #!/bin/sh
#        gawk -f /path/to/vbfilter.awk "$1"
#        EOF
#    2. define wrapper script as INPUT_FILTER in your Doxyfile:
#        INPUT_FILTER = /path/to/vbfilter.sh
#    3. take a look on the configuration options in the Configuration
#       section of this file (inside BEGIN function)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#---------------------------------------------------------------------------- 


#---------------------------------------------------------------------------- 
# TODO
#---------------------------------------------------------------------------- 
# type Date
# arrays -> () to []
# inline Linq
# anonymous functions / subs
# lambda expressions on multiple lines
# Handles
# Property with default value and a setter
# Conversions
# Dim test as testType = New testType With
# MyBase : i.e. MyBase.New
#---------------------------------------------------------------------------- 


BEGIN{
#############################################################################
# Configuration
#############################################################################
	# unix line breaks
	# set to 1 if using doxygen on unix with
	# windows formatted sources
	UnixLineBreaks = 1;
	
	# leading shift inside classes/namespaces/etc.
	# default is "\t" (tab)
	ShiftRight = "\t";
	#ShiftRight = "    ";
	
	# add namespace definition at the beginning using project directory name
	# should be enabled, if no explicit namespaces are used in the sources
	# but doxygen should recognize package names.
	# in C# unlike in VB .NET a namespace must always be defined
	leadingNamespace = 1;
	
	# Remove the blank lines if setted to 1
	removeBlankLines = 0;
	
	# Suffix added to an event's name to create it's handler method
	eventHandlerSuffix = "EventHandler";
	
#############################################################################
# helper variables, don't change
#############################################################################
	appShift="";
	ident = "";
	
	# Program behavior
	IsProperty = 0;
	IsInterface = 0;
	
	# Used to merge multiline statements
	fullLine=1;
	lastLine="";
	# Used for comments
	inlineComment = "";
	# Class names (array for nested classes)
	className[1] = "";
	classDefinition = "";
	classInheritance = "";
	genericTypeConstraint="";
	# Used to control nesting levels
	functionNestingLevel=0;
	classNestingLevel=0;
	# Used for properties
	hasPropertySetter = 1;
	setParameterName = "";
	propertyDefaultValue = "";
	# Used when method parameters are on multiple lines
	enumeratingParameters = 0;
	# With (stores the variable name used in the with statement)
	withVariable = "";
}

#############################################################################
# Program (main)
#############################################################################

Dos2Unix();

# Multiline statements (class with implements, properties, etc.)
classDefinition != "" {
	HandleInlineComment();
	HandleClass();
}
IsProperty {
	HandleInlineComment();
	HandleProperty();
}

GetLineShift();
HandleBlankLine(removeBlankLines);
HandleComments();

HandleOption();
HandleImport();
HandleRegion();

MergeMultiline();

HandleKeywords();
HandleNamespace();
HandleMethodAttribute();

HandleClass();
HandleInterface();
HandleProperty();
HandleEvent();

HandleConversions();
HandleStringConcatenation();
HandleSubFunction();
HandleVariable();
HandleWith();
HandleSelect();
HandleForForEach();
HandleTryCatch();
HandleIfElse();
HandleSyncLock();

HandleCodeLine();

#############################################################################
# shifter functions
#############################################################################
function AddShift() {
	appShift=appShift ShiftRight;
}

function ReduceShift() {
	appShift=substr(appShift,0,length(appShift)-length(ShiftRight));
}

function GetLineShift() {
	ident = gensub(/^([ \t]*).*$/, "\\1", "g", $0);
}

#############################################################################
# apply dos2unix
#############################################################################

function Dos2Unix() {
	if(UnixLineBreaks==1){
		sub(/\r$/,"")
	}
}

#############################################################################
# remove Option statements
#############################################################################

function HandleOption() {
	if(/.*Option[[:blank:]]+/) {
		next;
	}
}

#############################################################################
# Objects (construction, definition)
#############################################################################

function HandleObjects() {
	HandleOf();
	HandleNew();
	$0 = gensub(/([^ ]+) As ([^=]+)( =)?/, "\\2 \\1\\3", "g", $0);
	HandleLambdaExpression();
}

function HandleNew(strContent) {
	contentGiven = strContent;
	if(!strContent) {
		strContent = $0;
	}
	
	#Add missing parenthesis
	if(/\yNew (\w+\y(\.\w+\y)*) ?([^ .\(].+|)$/) {
		strContent = gensub(/(\yNew (\w+\y(\.\w+\y)*))( ?([^ .\(].+|))$/, "\\1()\\4", "g", strContent);
	}
	strContent = gensub(/(\y)New /, "\\1new ", "g", strContent);
	
	if(!contentGiven) {
		$0 = strContent;
	}
}

function HandleOf(strInput) {
	inputProvided = strInput;
	if(!inputProvided) {
		strInput = $0;
	}
	#Begin with nested Of
	while(match(strInput, /\(Of +(( *,? *[^ \(\)]+)+) *\)/)) {
		strInput = gensub(/\(Of +(( *,? *[^ \(\)]+)+) *\)/, "<\\1>", "g", strInput);
	}
	if(!inputProvided) {
		$0 = strInput;
	}
	
	return strInput;
}

function HandleLambdaExpression() {
	# inline
	if(/\y(Sub|Function) *\([^\)]+\) *[^ \t]+/) {
		$0 = gensub(/\y(Sub|Function) *\(([^\)]+)\)/, "\\2 =>", "g", $0);
	}
}

#############################################################################
# Functions
#############################################################################

# Handles VB conversion functions
function HandleConversions() {
	$0 = gensub(/(\y)CDate\(([^\)]+)\)/, "\\1Convert.ToDateTime(\\2)", "g", $0);
	$0 = gensub(/(\y)CInt\(([^\)]+)\)/, "\\1Convert.ToInt32(\\2)", "g", $0);
	$0 = gensub(/(\y)CBool\(([^\)]+)\)/, "\\1Convert.ToBoolean(\\2)", "g", $0);
	
	$0 = gensub(/(\y)(DirectCast|CType)\( *([^\(\),]+(\(.+\))*) *, *([^\(\),]+(\(.+\))*) *\)/, "\\1(\\5)\\3", "g", $0);
	$0 = gensub(/(\y)TryCast\( *([^\),]+) *, *([^\),]+) *\)/, "\\1(\\2 as \\3)", "g", $0);
}

# Checks if a keyword is contained within $0
# This function will remove any string that could make wrong matching
function ContainsKeyword(strKeyword) {
	strCopy = $0;
	while(match(strCopy,/"[^"]*"/)) {
		strCopy = gensub(/"[^"]*"/, "", "g", strCopy);
	}
	strPattern = "\\y" strKeyword "\\y";
	return strCopy ~ strPattern;
}

function HandleKeywords() {
	$0 = gensub(/(\y)Public(\y)/, "\\1public\\2", "g", $0);
	$0 = gensub(/(\y)Private(\y)/, "\\1private\\2", "g", $0);
	$0 = gensub(/(\y)Protected(\y)/, "\\1protected\\2", "g", $0);
	$0 = gensub(/(\y)MustInherit(\y)/, "\\1abstract\\2", "g", $0);
	$0 = gensub(/(\y)MustOverride(\y)/, "\\1abstract\\2", "g", $0);
	$0 = gensub(/(\y)Overridable(\y)/, "\\1virtual\\2", "g", $0);
	$0 = gensub(/(\y)Overrides(\y)/, "\\1override\\2", "g", $0);
	$0 = gensub(/(\y)Shared(\y)/, "\\1static\\2", "g", $0);
	$0 = gensub(/(\y)Const(\y)/, "\\1const\\2", "g", $0);
	
	$0 = gensub(/(\y)Return(\y)/, "\\1return\\2", "g", $0);
	# Avoid replacing ReadOnly of properties
	if(/(\y)ReadOnly(\y)/ && !/(\y)Property(\y)/) {
		$0 = gensub(/(\y)ReadOnly(\y)/, "\\1readonly\\2", "g", $0);
	}
	
	#Types
	$0 = gensub(/(\y)Integer(\y)/, "\\1int\\2", "g", $0);
	$0 = gensub(/(\y)UInteger(\y)/, "\\1uint\\2", "g", $0);
	$0 = gensub(/(\y)Long(\y)/, "\\1long\\2", "g", $0);
	$0 = gensub(/(\y)ULong(\y)/, "\\1ulong\\2", "g", $0);
	$0 = gensub(/(\y)Boolean(\y)/, "\\1bool\\2", "g", $0);
	$0 = gensub(/(\y)Double(\y)/, "\\1double\\2", "g", $0);
	$0 = gensub(/(\y)Decimal(\y)/, "\\1decimal\\2", "g", $0);
	$0 = gensub(/(\y)String(\y)/, "\\1string\\2", "g", $0);
	$0 = gensub(/(\y)Byte(\y)/, "\\1byte\\2", "g", $0);
	$0 = gensub(/(\y)SByte(\y)/, "\\1sbyte\\2", "g", $0);
	$0 = gensub(/(\y)Single(\y)/, "\\1float\\2", "g", $0);
	$0 = gensub(/(\y)Short(\y)/, "\\1short\\2", "g", $0);
	$0 = gensub(/(\y)UShort(\y)/, "\\1ushort\\2", "g", $0);
	#Boolean
	$0 = gensub(/(\y)True(\y)/, "\\1true\\2", "g", $0);
	$0 = gensub(/(\y)False(\y)/, "\\1false\\2", "g", $0);
	
	#Operators
	$0 = gensub(/(\y)Is(\y)/, "\\1is\\2", "g", $0);
	$0 = gensub(/(\y)Not /, "\\1! ", "g", $0);
	$0 = gensub(/ IsNot Nothing(\y)/, " != null\\1", "g", $0);
	$0 = gensub(" OrElse ", " || ", "g", $0);
	$0 = gensub(" Or ", " | ", "g", $0);
	#"AndAlso" and "And" managed in PrintGoNext
	gsub("<>", "!=");
	
	$0 = gensub(/(\y)Nothing(\y)/, "\\1null\\2", "g", $0);
	$0 = gensub(/(\y)Throw(\y)/, "\\1throw\\2", "g", $0);
	$0 = gensub(/(\y)Me(\y)/, "\\1this\\2", "g", $0);
}

#Condition specific replacement (i.e. = which is only comparison and not assignment)
function HandleCondition(strCondition) {
	strCondition = gensub(/([^!])=/, "\\1==", "g", strCondition);
	
	return strCondition;
}

function HandleStringConcatenation() {
	while(/" ?&/ || /& ?"/) {
		$0 = gensub(/&( ?)"/, "+\\1\"", "g", $0);
		$0 = gensub(/"( ?)&/, "\"\\1+", "g", $0);
	}
}

# Replaces br and p xHTML statements
function HandleXHTML(str) {
	if(/<br ?\/>/) {
		str = gensub(/<([^>]+)\/>/, "<\\1>", "g", str);
	}
	if(/<p ?\/>/) {
		str = gensub(/<([^>]+)\/>/, "<\\1></\\1>", "g", str);
	}
	
	return str;
}

# Takes functions / subs parameter (what is between parenthesis, without them) and converts them
# if removeType (2nd parameter) is setted, the function returns the parameters name only (comma separated)
function HandleParameters(parameter, removeType) {
	if(match(parameter, /,/)) {
		split(parameter, arrayParams, ",");
	} else {
		arrayParams[1] = parameter;
	}
	
	strReturn = "";
	regexResultPattern = "\\1\\3 \\2";
	if(removeType) {
		regexResultPattern = "\\1 \\2";
	}
	for (idx in arrayParams) {
		param = arrayParams[idx];
		
		sub("ByVal ", "", param);
		sub("ByRef ", "ref ", param);
		sub("Optional ", " ", param);
		HandleNew(param);
		
		if(strReturn == "") {
			strReturn = gensub(/[ \t]*(ref +)?([^ ]+) As ([^ ]+)/, regexResultPattern, "g", param);
		} else {
			strReturn = strReturn ", " gensub(/[ \t]*(ref +)?([^ ]+) As ([^ ]+)/, regexResultPattern, "g", param);
		}
	}
	delete arrayParams;
	return strReturn;
}

# Takes a For statement parameter (in an array, the parameter must be at the index 0)
# and returns an array containing "parameterType parameterName" (index 1), "parameterName" (index 2) 
function HandleForParameter(param) {
	param[1] = gensub(/[ \t]*([^ ]+) +As +([^ ]+)/, "\\2 \\1", "g", param[0]);
	param[2] = gensub(/[ \t]*([^ ]+) +As +([^ ]+).+/, "\\1", "g", param[0]);
}

#############################################################################
# Output / Print functions
#############################################################################

function AddPrintQueue(endLineChar, strLine) {
	idx = split(tmp, printQueue, " ");
	if(endLineChar) {
		strLine = strLine endLineChar;
	}
	printQueue[idx] = strLine;
}

function Print(endLineChar, textToPrint) {
	strLine = $0;
	if(textToPrint) {
		strLine = textToPrint;
	}
	if(endLineChar) {
		strLine = strLine endLineChar;
	}
	
	#Handle "AndAlso" and "And" here to avoid regex remplacement of character &
	strLine = gensub(/ AndAlso /, " \\&\\& ", "g", strLine);
	strLine = gensub(/ And /, " \\& ", "g", strLine);
	
	if(inlineComment != "") {
		print strLine " //" inlineComment;
		inlineComment = "";
	} else {
		print strLine;
	}
	
	for(idx in printQueue) {
		print printQueue[idx];
	}
	delete printQueue;
}

function PrintGoNext(endLineChar, textToPrint) {
	Print(endLineChar, textToPrint);
	next;
}

#############################################################################
# Parsing comments
#############################################################################

#Stores the inline comment and removes it from the line (better to put ending semicolon)
function HandleInlineComment() {
	strInlineComment = gensub(/^[^']+("[^"]*")/, "", "g", $0);
	if(/^[^']*'(.+)$/) {
		inlineComment = gensub(/^[^']*'(.+)$/, "\\1", "g", strInlineComment);
		replace = gensub(/^[^']*('.+)$/, "\\1", "g", strInlineComment);
		# If using sub, replace will be considered as regex pattern and should not
		replaceIdx = index($0, replace);
		$0 = substr($0, 0, replaceIdx - 1);
	}
}

function HandleCommentLine() {
	if(/^[ \t]*'/) {
		if(!/''' /) {
			sub("'''", "''' ");
		}
		sub(/'''/, "///");
		$0 = gensub(/^([ \t]*)'(.*)$/, "\\1//\\2", "g", $0);
		$0 = HandleXHTML($0);
		
		PrintGoNext();
	}
}

function HandleComments() {
	HandleCommentLine();
	HandleInlineComment();
}

#############################################################################
# merge multiline statements into one line
#############################################################################

function MergeMultiline() {
	if(fullLine == 0){
		fullLine = 1;
		# remove identation but keep a space
		$0 = gensub(/^[ \t]*/, " ", "g", $0);
		$0 = lastLine $0;
		lastLine="";
	}

	if(/[_,{=][ \t]*$/ || /\y(Or|OrElse|And|AndAlso)[ \t]*$/){
		fullLine=0;
		sub(/_$/,"");
		lastLine=$0;
		next;

	}
}

#############################################################################
# Imports statements
#############################################################################

function HandleImport() {
	if(/^([ \t]*)Imports (.+)$/) {
		$0 = gensub(/^([ \t]*)Imports (.+)$/, "\\1using \\2;", "g", $0);
		
		PrintGoNext();
	}
}

#############################################################################
# Namespace
#############################################################################

function HandleNamespace() {
	if(/^[ \t]*End Namespace/) {
		$0 = gensub(/([ \t]*)End Namespace/, "\\1}", "g", $0);
		
		PrintGoNext();
	}

	if(/^[ \t]*Namespace/) {
		$0 = gensub(/([ \t]*)Namespace +([^ \t]+)/, "\\1namespace \\2 {", "g", $0);
		
		PrintGoNext();
	}
}

#############################################################################
# Interface
#############################################################################

function HandleInterface() {
	if(/^[ \t]*End Interface/) {
		$0 = gensub(/([ \t]*)End Interface/, "\\1}", "g", $0);
		IsInterface = 0;
		PrintGoNext();
	}

	if(/\yInterface\y/) {
		$0 = gensub(/(.*)Interface +(.+)/, "\\1interface \\2 {", "g", $0);
		IsInterface = 1;
		PrintGoNext();
	}
}

#############################################################################
# Method attribute
#############################################################################

function HandleMethodAttribute() {
	if(/^[ \t]*<[^>]+>/) {
		$0 = gensub(/^([ \t]*)<([^>]+)>/, "\\1[\\2]", "g", $0);
	}
}

#############################################################################
# Class definition
#############################################################################

function HandleClassDefEnd() {
	strClass = classDefinition;
	if(classInheritance != "") {
		strClass = strClass " : " classInheritance;
		classInheritance = "";
	}
	if(genericTypeConstraint != "") {
		strClass = strClass " where " genericTypeConstraint;
		genericTypeConstraint = "";
	}
	classDefinition = "";
	
	Print("", strClass " {");
}

function HandleClassInheritance() {
	if(ContainsKeyword("(Inherits|Implements)")) {
		inheritance = gensub(/[ \t]*(Inherits|Implements) +(.+)/, "\\2", "g", $0);
		inheritance = HandleOf(inheritance);
		
		if(classInheritance == "") {
			classInheritance = inheritance;
		} else {
			classInheritance = classInheritance ", " inheritance;
		}
		
		next;
	} else {
		HandleClassDefEnd();
	}
}

function HandleClass() {
	#First match ending of class
	if(ContainsKeyword("End Class")) {
		$0 = gensub(/([ \t]*)End Class/, "\\1}", "g", $0);
		classNestingLevel--;
		
		PrintGoNext();
	}

	if(classDefinition != "") {
		HandleClassInheritance();
	}

	if(ContainsKeyword("Class")) {
		IsInClassDef = 1;
		className[classNestingLevel] = gensub(/^.*Class +([^ \(]+\y).*$/, "\\1", "g", $0);
		
		#Stores and remove generic type constraint
		if(/.*Class +([^\( ]+) *\(Of +([^ \)]+) *As *([^\) ]+)\)/) {
			genericTypeConstraint = gensub(/.*Class +[^\( ]+ *\(Of +([^ \)]+) *As *([^\) ]+)\)/, "\\1 : \\2", "g", $0);
			$0 = gensub(/(.*Class +[^\( ]+ *\(Of +[^ \)]+) *As *([^\) ]+)\)/, "\\1)", "g", $0);
		}
		
		#Generic type
		if(/Class +[^\(]+\(Of +([^ \)]+)\)/) {
			$0 = gensub(/(.*Class +[^\(]+)\(Of +([^ \)]+) *\)/, "\\1<\\2>", "g", $0);
		}
		
		if(ContainsKeyword("Partial")) {
			$0 = gensub(/\y(Partial\y)/, "", "g", $0);
			$0 = gensub(/(.+)Class +([^ \(]+)/, "\\1 partial class \\2", "g", $0);
		} else {
			$0 = gensub(/(.+)Class +([^ \(]+)/, "\\1 class \\2", "g", $0);
		}
		classNestingLevel++;
		
		classDefinition = $0;
		
		next;
	}
}

#############################################################################
# Properties definition
#############################################################################

function HandleProperty() {
	HandlePropertyNextLines();
	HandlePropertyFirstLine();
}

function HandlePropertyEnd() {
	IsProperty = 0;
	
	if(waitEndProperty) {
		PrintGoNext("", ident "}");
	} else {
		if(hasPropertySetter) {
			Print(";", ident "\tget");
			Print(";", ident "\tset");
		} else {
			if(propertyDefaultValue) {
				Print("", ident "\tget { return " propertyDefaultValue "; }");
			} else {
				Print(";", ident "\tget");
			}
		}
		Print("}", ident);
	}
}

function HandlePropertyNextLines() {
	if(IsProperty) {
		#Closing getter or setter
		if(/^[ \t]*End +(Get|Set)[ \t]*$/) {
			$0 = gensub(/([ \t]*)End +(Get|Set)/, "\\1}", "g", $0);
			PrintGoNext();
		}

		#Closing property or starting getter
		if(/^[ \t]*(Get|End Property)[ \t]*$/) {
				waitEndProperty = 1;
			
			if(/Get/) {
				$0 = gensub(/([ \t]*)Get/, "\\1get {", "g", $0);
				PrintGoNext();
			}
		}
		
		#Starting setter
		if(/^[ \t]*Set[ \(].*$/) {
			waitEndProperty = 1;
			
			#Keep set parameter name to replace it
			setParameterName = gensub(/([ \t]*)Set *\(( *(ByVal|ByRef))? *([^ ]+) As [^\)]+\)/, "\\4", "g", $0);
			#Just let the set instruction
			$0 = gensub(/([ \t]*)Set(.+)/, "\\1set {", "g", $0);
			
			PrintGoNext();
		}
		
		if(setParameterName != "") {
			sub(setParameterName, "value");
		}
	}
	
	if(/\yEnd Property\y/ || (IsProperty && !waitEndProperty)) {
		HandlePropertyEnd();
	}
}

function HandlePropertyFirstLine() {
	if(ContainsKeyword("Property")) {
		IsProperty = 1;
		hasPropertySetter = 1;
		propertyDefaultValue = "";
		waitEndProperty = 0;
		setParameterName = "";
		
		sub("Property ", "");
		
		$0 = gensub(/([ \t]*[^ ]+) ([^ ]+) As ([^ ]+)/, "\\1 \\3 \\2 {", "g", $0);
		
		if(ContainsKeyword("ReadOnly")){
			hasPropertySetter = 0;
			sub("ReadOnly ", "", $0);
		}
		
		#Default value
		if(/=/) {
			propertyDefaultValue = gensub(/^.+ ?= ?(.+)$/, "\\1", "g", $0);
			$0 = gensub(/^(.+) ?= ?(.+)$/, "\\1", "g", $0);
		}
		
		PrintGoNext();
	}
}

#############################################################################
# Sub / Function definitions
#############################################################################

function HandleSubFunction() {
	#First match ending of sub or function
	if(/End (Sub|Function)/) {
		$0 = gensub(/([ \t]*)End (Sub|Function)/, "\\1}", "g", $0);
		functionNestingLevel--;
		
		PrintGoNext();
	}

	if(/^[ \t]*Exit +Sub/) {
		$0 = gensub(/^([ \t]*)Exit Sub/, "\\1return", "g", $0);
		PrintGoNext(";");
	}

	#Then match sub or function itself (avoid anonymous function)
	if(ContainsKeyword("(Sub|Function) +[^ \\(]+")) {
		genericTypeConstraint = "";
		
		# Handle (Of Type) to remove parenthesis (easier to handle the rest)
		HandleOf();
		
		#Stores and remove generic type constraint
		if(/.*(Sub|Function) +[^\( ]+ *< *.+ +As +(.+)> *\(.*\)/) {
			genericTypeConstraint = gensub(/^.*(Sub|Function) +[^\( ]+ *< *(.+) +As +(.+)> *\(.*\).+$/, " where \\2 : \\3", "g", $0);
			$0 = gensub(/(.*(Sub|Function) +[^\( ]+ *< *.+) +As +.+>( *\(.*\))/, "\\1>\\3", "g", $0);
		}
		
		if(ContainsKeyword("Implements")) {
			interfaceMethodName = gensub(/^.+\yImplements\y(.+)$/, "\\1", "g", $0);
			
			#remove implements from current line
			$0 = gensub(/\yImplements\y.+$/, "", "g", $0);
			
			if(/\yFunction\y/) {
				classMethodName = gensub(/^.*Function +([^\(]+)(\([^\)]*\)) +As +.+$/, "\\1", "g", $0);
				interfaceMethod = gensub(/^(.*)Function +([^\(]+)(\([^\)]*\)) +As +([^ \(]+)/, "\\4 " interfaceMethodName "\\3 {", "g", $0);
		
			} else {
				classMethodName = gensub(/^.*Sub +([^\(]+)(\([^\)]*\)).+$/, "\\1", "g", $0);
				interfaceMethod = gensub(/^(.*)Sub +([^\(]+)(\([^\)]*\))/, "void " interfaceMethodName "\\3 {", "g", $0);
			}
				

			methodParams = "";
			methodParams = gensub(/.*\(([^\)]*)\).*/, "\\1", "g", interfaceMethod);
			methodParamsNoType = HandleParameters(methodParams, 1);
			methodParams = HandleParameters(methodParams);
			interfaceMethod = gensub(/\(([^\)]*)\)/, "(" methodParams ")", "g", interfaceMethod);
		
			sub(/\yabstract\y/, "", interfaceMethod);
			
			Print("", ident interfaceMethod);
			if(ContainsKeyword("Function")) {
				Print(";", ident "\treturn " classMethodName "(" methodParamsNoType ")" genericTypeConstraint);
			} else {
				Print(";", ident "\t" classMethodName "(" methodParamsNoType ")" genericTypeConstraint);
			}
			Print("}", ident);
		}
		
		if(ContainsKeyword("Sub New")) {
			#Match constructors
			$0 = gensub(/Sub +New(.+)/, className[classNestingLevel - 1] "\\1", "g", $0);
		} else if (ContainsKeyword(" Sub ")) {
			#Match void methods
			$0 = gensub(/Sub +([^ \(]+)\(([^\)]*)\)/, "void \\1(\\2)", "g", $0);
			#Sub not entirely on one line 
			$0 = gensub(/Sub +([^ \(]+)\([ \t]*$/, "void \\1(", "g", $0);
		} else {
			#Match regular methods
			$0 = gensub(/Function +([^\(]+)(\([^\)]*\)) +As +(.+)/, " \\3 \\1\\2", "g", $0);
		}
		
		methodParams = "";
		methodParams = gensub(/.*\(([^\)]*)\).*/, "\\1", "g", $0);
		methodParams = HandleParameters(methodParams);
		$0 = gensub(/\(([^\)]*)\)/, "(" methodParams ")" genericTypeConstraint, "g", $0);
		
		functionNestingLevel++;
		
		if(ContainsKeyword(" abstract ") || IsInterface) {
			PrintGoNext(";");
		} else if (/[\(][ \t]*$/) {
			PrintGoNext();
		} else {
			$0 = $0 " {";
			PrintGoNext();
		}
	}
}

#############################################################################
# Char definitions
#############################################################################

function HandleChar() {
	if(/"[^"]"c/) {
		$0 = gensub(/"([^"])"c/, "'\\1'", "g", $0);
	}
}

#############################################################################
# Variable definition
#############################################################################

function HandleVariable() {
	if(/^[ \t]*Dim ([^ ]+) As New ([^ =]+)/) {
		# New handled by HandleObjects()
		$0 = gensub(/^([ \t]*)Dim ([^ ]+) As +New +([^ =\(]+)(.+)/, "\\1 \\3 \\2 = New \\3\\4", "g", $0);
		HandleObjects();
		# New ... With { ... }
		containsWith = 0;
		if(ContainsKeyword("With")) {
			containsWith = 1;
			$0 = gensub(/(\y)With(\y)/, "\\1", "g", $0);
		}
		$0 = gensub(/([^A-Za-z_0-9])\./, "\\1", "g", $0);
		
		if(/[\(,][ \t]*$/) {
			enumeratingParameters = 1;
			PrintGoNext();
		} else if (containsWith && !/}[ \t]*$/) {
			PrintGoNext();
		} else {
			PrintGoNext(";");
		}
	}

	if(/^[ \t]*Dim ([^ ]+) As ([^=]+)/) {
		$0 = gensub(/^([ \t]*)Dim\y(.+)/, "\\1\\2", "g", $0);
		HandleObjects();
		
		if(/[\(,][ \t]*$/) {
			enumeratingParameters = 1;
			PrintGoNext();
		} else {
			PrintGoNext(";");
		}
	}

	if(/^[ \t]*Dim ([^ =]+) *=/) {
		$0 = gensub(/^([ \t]*)Dim\y(.+)/, "\\1dynamic \\2", "g", $0);
		HandleObjects();
		
		if(/[\(,][ \t]*$/) {
			enumeratingParameters = 1;
			PrintGoNext();
		} else {
			PrintGoNext(";");
		}
	}
}

#############################################################################
# Region statements
#############################################################################

function HandleRegion() {
	if(/^#Region[[:blank:]]*/ || /^[ \t]*#End +Region[[:blank:]]*/) {
		sub("#Region", "#region");
		sub("#End +Region", "#endregion");
		PrintGoNext();
	}
}

#############################################################################
# Blank lines
#############################################################################

function HandleBlankLine(remove) {
	if(/^\s*$/ && !remove) {
		PrintGoNext();
	}
}

#############################################################################
# With statement
#############################################################################

function HandleWith() {
	if(/^[ \t]*End With/) {
		withVariable = "";
		$0 = "";
		PrintGoNext();
	}

	if(/[\(, \t]+\./) {
		while(/[\(, \t]+\./ && withVariable != "") {
			$0 = gensub(/([\(, \t]+)(\..+)/, "\\1" withVariable "\\2", "g", $0);
		}
		PrintGoNext(";");
	}

	if(/^[ \t]*With /) {
		withVariable = gensub(/^[ \t]*With +(.+)/, "\\1", "g", $0);
		#trim right
		sub(/[ \t]+$/, "", withVariable);
		$0 = "";
		PrintGoNext();
	}
}

#############################################################################
# Select statement
#############################################################################

function HandleSelect() {
	if(/^[ \t]*End Select/) {
		$0 = gensub(/([ \t]*)End +Select/, "\\1}", "g", $0);
		PrintGoNext();
	}

	if(/^[ \t]*Case +Else\y/) {
		$0 = gensub(/^([ \t]*)Case +Else\y/, "\\1default", "g", $0);
		PrintGoNext(":");
	}

	if(/^[ \t]*Case /) {
		if(caseClause != "") {
			Print(";", ident "\tbreak");
		}
		
		caseClause = gensub(/^[ \t]*Case +(.+)/, "\\1", "g", $0);
		split(caseClause, cases, ",");
		$0 = "";
		for (idx in cases) {
			$0 = $0 ident "case " cases[idx] ":\n";
		}
		PrintGoNext();
	}

	if(/^[ \t]*Select +Case /) {
		$0 = gensub(/^([ \t]*)Select +Case +(.+)/, "\\1switch(\\2) {", "g", $0);
		caseClause = "";
		PrintGoNext();
	}
}

#############################################################################
# For / For Each statement
#############################################################################

function HandleForForEach() {
	if(/^[ \t]*Next\y/) {
		$0 = gensub(/([ \t]*)Next\y/, "\\1}", "g", $0);
		PrintGoNext();
	}

	if(/^[ \t]*Exit +For\y/) {
		$0 = gensub(/([ \t]*)Exit +For\y/, "\\1break", "g", $0);
		PrintGoNext(";");
	}

	if(/^[ \t]*For Each\y/) {
		param = HandleParameters(gensub(/^[ \t]*For Each +(.+) +In +.+/, "\\1", "g", $0));
		$0 = gensub(/^([ \t]*)For Each +(.+) +In +(.+)/, "\\1foreach(" param " in \\3) {", "g", $0);

		PrintGoNext();
	}

	if(/^[ \t]*For\y/) {
		condition = gensub(/^[ \t]*For +.+ +To +(.+)/, "\\1", "g", $0);
		resParam[0] = gensub(/^[ \t]*For +(.+) +To.+/, "\\1", "g", $0);
		HandleForParameter(resParam);
		
		$0 = "for(" resParam[1] ";" resParam[2] " <= " condition ";" resParam[2] "++) {"

		PrintGoNext();
	}
}

#############################################################################
# Try Catch
#############################################################################

function HandleTryCatch() {
	if(/^[ \t]*End +Try\y/) {
		$0 = gensub(/([ \t]*)End +Try/, "\\1}", "g", $0);

		PrintGoNext();
	}

	if(/^[ \t]*Try\y/) {
		$0 = gensub(/([ \t]*)Try/, "\\1try {", "g", $0);

		PrintGoNext();
	}

	if(/^[ \t]*Finally\y/) {
		$0 = gensub(/([ \t]*)Finally/, "\\1} finally {", "g", $0);

		PrintGoNext();
	}

	if(/^[ \t]*Catch\y/) {
		if(/Catch +[^ ]+ +As +.+/) {
			variable = HandleParameters(gensub(/Catch +([^ ]+ +As +.+)/, "\\1", "g", $0));
			$0 = gensub(/^([ \t]*)Catch +([^ ]+ +As +.+)/, "\\1} catch(" variable ") {", "g", $0);
		} else {
			$0 = gensub(/([ \t]*)Catch/, "\\1} catch {", "g", $0);
		}

		PrintGoNext();
	}
}

#############################################################################
# Events
#############################################################################

function HandleEvent() {
	if(ContainsKeyword("Event")) {
		eventName = gensub(/^.+ +Event +(\w+)\y.+$/, "\\1", "g", $0);
		HandleOf();
		eventHandlerParams = gensub(/^.+ +Event +\w+ ?\(([^\)]+)\).*$/, "\\1", "g", $0);
		eventHandlerParams = HandleParameters(eventHandlerParams);
		
		AddPrintQueue(";", gensub(/^(.+ +)Event +(\w+)\y.+$/, "\\1delegate void " eventName eventHandlerSuffix "(" eventHandlerParams ")", "g", $0));
		
		$0 = gensub(/^(.+ +)Event +(\w+)\y.+$/, "\\1event " eventName eventHandlerSuffix " " eventName, "g", $0);
		PrintGoNext(";");
	}
	
	if(ContainsKeyword("RaiseEvent")) {
		sub("RaiseEvent ", "");
	}
}

#############################################################################
# SyncLock
#############################################################################

function HandleSyncLock() {
	if(/^[ \t]*End +SyncLock\y/) {
		$0 = gensub(/([ \t]*)End +SyncLock/, "\\1}", "g", $0);

		PrintGoNext();
	}
	
	if(/^[ \t]*SyncLock\y/) {
		$0 = gensub(/([ \t]*)SyncLock +([^ \t]+)/, "\\1lock(\\2) {", "g", $0);

		PrintGoNext();
	}
}

#############################################################################
# If Else
#############################################################################

function HandleIfElse() {
	if(/^[ \t]*End +If/) {
		$0 = gensub(/([ \t]*)End +If/, "\\1}", "g", $0);
		PrintGoNext();
	}
	
	# Compiler condition
	if(/^[ \t]*#(End )?If/) {
		PrintGoNext();
	}
	
	if(/^[ \t]*(Else)?If .+ Then/) {
		condition = gensub(/^[ \t]*(Else)?If +(.+) +Then(\y.+)?/, "\\2", "g", $0);
		inlineThen = gensub(/^[ \t]*(Else)?If +(.+) +Then(\y.+)?/, "\\3", "g", $0);
		
		condition = HandleCondition(condition);
		#Made by concatenation to avoid interpreting & of the condition
		if(/\yElseIf\y/) {
			$0 = ident "} else if (" condition ") { " inlineThen;
		} else {
			$0 = ident "if (" condition ") { " inlineThen;
		}
		
		if(!match(inlineThen, /^[ \t]*$/)) { #IsNullOrWhiteSpace
			$0 = $0 " }";
		}
		
		if(/[{}][ \t]*$/) {
			PrintGoNext();
		} else {
			PrintGoNext(";");
		}
	}

	if(/^[ \t]*Else/) {
		$0 = gensub(/([ \t]*)Else/, "\\1} else {", "g", $0);
		PrintGoNext();
	}
}

#############################################################################
# Code lines
#############################################################################

function HandleCodeLine() {
	if(/.*/) {
		if(enumeratingParameters && /\)[ \t]*$/) {
			enumeratingParameters = 0;
		}

		HandleObjects();
		HandleChar();
		
		if(enumeratingParameters) {
			PrintGoNext();
		} else {
			PrintGoNext(";");
		}
	}
}