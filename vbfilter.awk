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


BEGIN{
#############################################################################
# Configuration
#############################################################################
	# unix line breaks
	# set to 1 if using doxygen on unix with
	# windows formatted sources
	UnixLineBreaks=1;
	
	# leading shift inside classes/namespaces/etc.
	# default is "\t" (tab)
	ShiftRight="\t";
	#ShiftRight="    ";
	
	# add namespace definition at the beginning using project directory name
	# should be enabled, if no explicit namespaces are used in the sources
	# but doxygen should recognize package names.
	# in C# unlike in VB .NET a namespace must always be defined
	leadingNamespace=1;
	
#############################################################################
# helper variables, don't change
#############################################################################
	appShift="";
	
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
	IsProperty = 0;
	hasPropertySetter = 1;
	setParameterName = "";
	# Used when method parameters are on multiple lines
	enumeratingParameters = 0;
	#With
	withVariable = "";
}

#############################################################################
# shifter functions
#############################################################################
function AddShift() {
	appShift=appShift ShiftRight;
}

function ReduceShift() {
	appShift=substr(appShift,0,length(appShift)-length(ShiftRight));
}

#############################################################################
# apply dos2unix
#############################################################################
UnixLineBreaks==1{
	sub(/\r$/,"")
}

#############################################################################
# merge multiline statements into one line
#############################################################################
fullLine==0{
	fullLine=1;
	$0= lastLine$0;
	lastLine="";
}
/[_,{][ \t]*$/ || /\y(Or|OrElse|And|AndAlso)[ \t]*$/{
	fullLine=0;
 	sub(/_$/,"");
 	lastLine=$0;
 	next;

}

#############################################################################
# remove leading whitespaces and tabs
#############################################################################
/^[ \t]/{
	sub(/^[ \t]*/, "")
}

#############################################################################
# remove Option statements
#############################################################################

/.*Option[[:blank:]]+/ {
	next;
}


#############################################################################
# remove Option and Region statements
#############################################################################

function IsCommentLine() {
	if(/^[ \t]*'/) {
		return 1;
	}
	return 0;
}

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

function HandleKeywords() {
	$0 = gensub(/(\y)Public(\y)/, "\\1public\\2", "g", $0);
	$0 = gensub(/(\y)Private(\y)/, "\\1private\\2", "g", $0);
	$0 = gensub(/(\y)Protected(\y)/, "\\1protected\\2", "g", $0);
	$0 = gensub(/(\y)MustInherit(\y)/, "\\1abstract\\2", "g", $0);
	$0 = gensub(/(\y)Overridable(\y)/, "\\1virtual\\2", "g", $0);
	$0 = gensub(/(\y)Overrides(\y)/, "\\1override\\2", "g", $0);
	
	$0 = gensub(/(\y)Return(\y)/, "\\1return\\2", "g", $0);
	
	#Types
	$0 = gensub(/(\y)Integer(\y)/, "\\1int\\2", "g", $0);
	$0 = gensub(/(\y)Boolean(\y)/, "\\1bool\\2", "g", $0);
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

function HandleXHTML(str) {
	if(/<br ?\/>/) {
		str = gensub(/<([^>]+)\/>/, "<\\1>", "g", str);
	}
	if(/<p ?\/>/) {
		str = gensub(/<([^>]+)\/>/, "<\\1></\\1>", "g", str);
	}
	
	return str;
}

function HandleParameters(parameter) {
	if(match(parameter, /,/)) {
		split(parameter, arrayParams, ",");
	} else {
		arrayParams[1] = parameter;
	}
	
	strReturn = "";
	for (idx in arrayParams) {
		param = arrayParams[idx];
		
		sub("ByVal ", "", param);
		sub("ByRef ", "ref ", param);
		param = gensub(/([ ,])New /, "\\1new ", "g", param);
		
		if(strReturn == "") {
			strReturn = gensub(/[ \t]*(ref +)?([^ ]+) As ([^ ]+)/, "\\1\\3 \\2", "g", param);
		} else {
			strReturn = strReturn ", " gensub(/[ \t]*(ref +)?([^ ]+) As ([^ ]+)/, "\\1\\3 \\2", "g", param);
		}
	}
	delete arrayParams;
	return strReturn;
}

function HandleForParameter(param) {
	param[1] = gensub(/[ \t]*([^ ]+) +As +([^ ]+)/, "\\2 \\1", "g", param[0]);
	param[2] = gensub(/[ \t]*([^ ]+) +As +([^ ]+).+/, "\\1", "g", param[0]);
}

function PrintGoNext(endLineChar) {
	strLine = $0
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
	next;
}

#############################################################################
# Parsing comments
#############################################################################

IsCommentLine() {
	$0 = gensub(/'''/, "///", "g", $0);
	$0 = gensub(/^[ \t]*'(.+)$/, "//\\1", "g", $0);
	$0 = HandleXHTML($0);
	
	print $0;
	next;
}

#Stores the inline comment and removes it from the line (better to put ending semicolon)
HandleInlineComment();

#############################################################################
# Region statements
#############################################################################

/^#Region[[:blank:]]*/ || /^[ \t]*#End +Region[[:blank:]]*/{
	sub("#Region", "#region");
	sub("#End +Region", "#endregion");
	PrintGoNext();
}

#############################################################################
# Imports statements
#############################################################################

/^([ \t]*)Imports (.+)$/ {
	$0 = gensub(/^([ \t]*)Imports (.+)$/, "\\1using \\2;", "g", $0);
	
	PrintGoNext();
}

#############################################################################
# Keywords (public, private, nothing, etc.)
#############################################################################

HandleKeywords();

#############################################################################
# Namnespace
#############################################################################

/^[ \t]*End Namespace/ {
	$0 = gensub(/([ \t]*)End Namespace/, "\\1}", "g", $0);
	
	PrintGoNext();
}

/^[ \t]*Namespace/ {
	$0 = gensub(/([ \t]*)Namespace +([^ \t]+)/, "\\1namespace \\2 {", "g", $0);
	
	PrintGoNext();
}

#############################################################################
# Class definition
#############################################################################

#First match ending of class
/End Class/ {
	$0 = gensub(/([ \t]*)End Class/, "\\1}", "g", $0);
	classNestingLevel--;
	
	PrintGoNext();
}

classDefinition != "" {
	if(/(Inherits|Implements)/) {
		inheritance = gensub(/(Inherits|Implements) +(.+)/, "\\2", "g", $0);
		if(classInheritance == "") {
			classInheritance = inheritance;
		} else {
			classInheritance = ", " inheritance;
		}
	
		next;
	} else {
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
		
		print strClass " {";
	}
}

/ Class / {
	IsInClassDef = 1;
	className[classNestingLevel] = gensub(/.+Class +([^ \(]+).+/, "\\1", "g", $0);
	
	#Stores and remove generic type constraint
	if(/.*Class +([^\( ]+) *\(Of +([^ \)]+) *As *([^\) ]+)\)/) {
		genericTypeConstraint = gensub(/.*Class +[^\( ]+ *\(Of +([^ \)]+) *As *([^\) ]+)\)/, "\\1 : \\2", "g", $0);
		$0 = gensub(/(.*Class +[^\( ]+ *\(Of +[^ \)]+) *As *([^\) ]+)\)/, "\\1)", "g", $0);
	}
	
	#Generic type
	if(/Class +[^\(]+\(Of +([^ \)]+)\)/) {
		$0 = gensub(/(.*Class +[^\(]+)\(Of +([^ \)]+) *\)/, "\\1<\\2>", "g", $0);
	}
	
	$0 = gensub(/(.+)Class +([^ \(]+)/, "\\1 class \\2", "g", $0);
	classNestingLevel++;
	
	classDefinition = $0;
	next;
}

#############################################################################
# Properties definition
#############################################################################

IsProperty {
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
	
	#Property with default getter / setter
	if(!waitEndProperty){
		print "get;";
		if(hasPropertySetter) {
			print "set;";
		}
	}
	
	if(setParameterName != "") {
		sub(setParameterName, "value");
	}
}

/End Property/ || (IsProperty && !waitEndProperty) {
	IsProperty = 0;
	hasPropertySetter = 1;
	waitEndProperty = 0;
	setParameterName = "";
	
	$0 = "}";
	PrintGoNext();
}

/ Property / {
	IsProperty = 1;
	
	sub("Property ", "");
	
	if(/[ \t]*[^ ]+ ([^ ]+) As ([^ ]+)/) {
		$0 = gensub(/([ \t]*[^ ]+) ([^ ]+) As ([^ ]+)/, "\\1 \\3 \\2 {", "g", $0);
	}
	
	if(/ ReadOnly /){
		hasPropertySetter = 0;
		sub("ReadOnly ", "", $0);
	}
	
	PrintGoNext();
}

#############################################################################
# Sub / Function definitions
#############################################################################

#First match ending of sub or function
/End (Sub|Function)/ {
	$0 = gensub(/([ \t]*)End (Sub|Function)/, "\\1}", "g", $0);
	functionNestingLevel--;
	
	PrintGoNext();
}

/^[ \t]*Exit +Sub/ {
	$0 = gensub(/^([ \t]*)Exit Sub/, "\\1return", "g", $0);
	PrintGoNext(";");
}

#Then match sub or function itself
/ (Sub|Function) / {
	if(/Sub New/) {
		#Match constructors
		$0 = gensub(/Sub +New(.+)/, className[classNestingLevel - 1] "\\1", "g", $0);
	} else if (/ Sub /) {
		#Match void methods
		$0 = gensub(/Sub +([^ \(]+)\(([^\)]*)\)/, "void \\1(\\2)", "g", $0);
		#Sub not entirely on one line 
		$0 = gensub(/Sub +([^ \(]+)\([ \t]*$/, "void \\1(", "g", $0);
	} else {
		#Match regular methods
		$0 = gensub(/Function +([^ \(]+)(\([^\)]*\)) +As +([^ \(]+( ?\(Of +[^ \)]+\))?)/, " \\3 \\1\\2", "g", $0);
		$0 = gensub(/\(Of +([^ \)]+) *\)/, "<\\1>", "g", $0);
	}
	
	methodParams = "";
	methodParams = gensub(/.*\(([^\)]*)\).*/, "\\1", "g", $0);
	methodParams = HandleParameters(methodParams);
	$0 = gensub(/\(([^\)]*)\)/, "(" methodParams ")", "g", $0);
	
	functionNestingLevel++;
	
	if(/ MustOverride /) {
		sub("MustOverride", "abstract");
		PrintGoNext(";");
	} else if (/[\(][ \t]*$/) {
		PrintGoNext();
	} else {
		$0 = $0 " {";
		PrintGoNext();
	}
}

#############################################################################
# Char definitions
#############################################################################

/"[^"]"c/ {
	$0 = gensub(/"([^"])"c/, "'\\1'", "g", $0);
}

#############################################################################
# Variable definition
#############################################################################

/^[ \t]*Dim ([^ ]+) As New ([^ =]+)/ {
	$0 = gensub(/^([ \t]*)Dim ([^ ]+) As +New +([^ =\(]+)(.+)/, "\\1 \\3 \\2 = new \\3\\4", "g", $0);
	#Could be a new statement within the parameters
	$0 = gensub(/(\y)New /, "\\1new ", "g", $0);
	# Dim example As List = New List(Of Object)
	$0 = gensub(/\(Of +([^ \)]+) *\)/, "<\\1>", "g", $0);
	# New ... With { ... }
	containsWith = 0;
	if(/(\y)With(\y)/) {
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

/^[ \t]*Dim ([^ ]+) As ([^ =]+)/ {
	$0 = gensub(/^([ \t]*)Dim ([^ ]+) As ([^ =]+)/, "\\1 \\3 \\2", "g", $0);
	
	if(/[\(,][ \t]*$/) {
		enumeratingParameters = 1;
		PrintGoNext();
	} else {
		PrintGoNext(";");
	}
}

#############################################################################
# Attributes (at the end because it's generic, handle the more specific regex before)
#############################################################################

#Protected mobjReportParameters As ReportParametersType
/^[ \t]*[^ ]+ ([^ ]+) As ([^ ]+)/ && !/^[ \t]*For\y/ {
	$0 = gensub(/^([ \t]*[^ ]+) ([^ ]+) As ([^ ]+)/, "\\1 \\3 \\2", "g", $0);
	
	PrintGoNext(";");
}

#############################################################################
# Blank lines
#############################################################################

/^[[:blank:]]+$/ || $0 == "" {
	PrintGoNext();
}

#############################################################################
# With statement
#############################################################################

/^[ \t]*End With/ {
	withVariable = "";
	$0 = "";
	PrintGoNext();
}

/[ \t]+\./ && withVariable != "" {
	$0 = gensub(/([ \t]+)(\..+)/, "\\1" withVariable "\\2", "g", $0);
	PrintGoNext(";");
}

/^[ \t]*With / {
	withVariable = gensub(/^[ \t]*With +(.+)/, "\\1", "g", $0);
	#trim right
	sub(/[ \t]+$/, "", withVariable);
	$0 = "";
	PrintGoNext();
}

#############################################################################
# Select statement
#############################################################################

/^[ \t]*End Select/ {
	$0 = gensub(/([ \t]*)End +Select/, "\\1}", "g", $0);
	PrintGoNext();
}

/^[ \t]*Case +Else\y/ {
	$0 = gensub(/^([ \t]*)Case +Else\y/, "\\1default", "g", $0);
	PrintGoNext(":");
}

/^[ \t]*Case / {
	space = gensub(/^([ \t]*)Case.+/, "\\1", "g", $0);
	caseClause = gensub(/^[ \t]*Case +(.+)/, "\\1", "g", $0);
	split(caseClause, cases, ",");
	$0 = "";
	for (idx in cases) {
		$0 = $0 space "case " cases[idx] ":\n";
	}
	PrintGoNext();
}

/^[ \t]*Select +Case / {
	$0 = gensub(/^([ \t]*)Select +Case +(.+)/, "\\1switch(\\2) {", "g", $0);
	PrintGoNext();
}

#############################################################################
# For / For Each statement
#############################################################################

/^[ \t]*Next\y/ {
	$0 = gensub(/([ \t]*)Next\y/, "\\1}", "g", $0);
	PrintGoNext();
}

/^[ \t]*Exit +For\y/ {
	$0 = gensub(/([ \t]*)Exit +For\y/, "\\1break", "g", $0);
	PrintGoNext(";");
}

/^[ \t]*For Each\y/ {
	$0 = gensub(/^([ \t]*)For Each +(.+) +In +(.+)/, "\\1foreach(" HandleParameters("\\2") " in \\3) {", "g", $0);

	PrintGoNext();
}

/^[ \t]*For\y/ {
	#condition = gensub(/^([ \t]*)For +(.+) +To +(.+)/, "\\1for(" HandleForParameter("\\2") " To \\3) {", "g", $0);
	condition = gensub(/^[ \t]*For +.+ +To +(.+)/, "\\1", "g", $0);
	param = gensub(/^[ \t]*For +(.+) +To.+/, "\\1", "g", $0);
	resParam[0] = param;
	HandleForParameter(resParam);
	
	$0 = "for(" resParam[1] ";" resParam[2] " <= " condition ";" resParam[2] "++) {"

	PrintGoNext();
}

#############################################################################
# Conditions
#############################################################################


/^[ \t]*End +If/ {
	$0 = gensub(/([ \t]*)End +If/, "\\1}", "g", $0);
	PrintGoNext();
}

/^[ \t]*Else/ {
	$0 = gensub(/([ \t]*)Else/, "} else {", "g", $0);
	PrintGoNext();
}

/[ \t]*If .+ Then/ {
	condition = gensub(/^[ \t]*If +(.+) +Then(\y.+)?/, "\\1", "g", $0);
	inlineThen = gensub(/^[ \t]*If +(.+) +Then(\y.+)?/, "\\2", "g", $0);
	condition = HandleCondition(condition);
	$0 = gensub(/^([ \t]*)If +.+ Then(\y.+)?/, "\\1", "g", $0);
	#Made by concatenation to avoid interpreting & of the condition
	$0 = $0 "if (" condition ") { " inlineThen;
	
	if(!match(inlineThen, /^[ \t]*$/)) { #IsNullOrWhiteSpace
		$0 = $0 " }";
	}
	
	if(/[{}][ \t]*$/) {
		PrintGoNext();
	} else {
		PrintGoNext(";");
	}
}

#############################################################################
# Code lines
#############################################################################

/.*/ {
	if(enumeratingParameters && /\)[ \t]*$/) {
		enumeratingParameters = 0;
	}
	
	$0 = gensub(/ Nothing([ ,]?)/, " null\\1", "g", $0);
	$0 = gensub(/([ ,])New /, "\\1new ", "g", $0);
	
	if(enumeratingParameters) {
		PrintGoNext();
	} else {
		PrintGoNext(";");
	}
}