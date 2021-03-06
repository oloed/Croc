module croctest;

import tango.core.tools.TraceExceptions;
import tango.io.Stdout;

import croc.api;
import croc.compiler;

import croc.addons.pcre;
import croc.addons.sdl;
import croc.addons.gl;
import croc.addons.net;
import croc.addons.devil;

import croc.ex_doccomments;

uword processComment_wrap(CrocThread* t)
{
	auto str = checkStringParam(t, 1);
	checkParam(t, 2, CrocValue.Type.Table);
	processComment(t, str);
	return 1;
}

version(CrocAllAddons)
{
	version = CrocPcreAddon;
	version = CrocSdlAddon;
	version = CrocGlAddon;
	version = CrocNetAddon;
	version = CrocDevilAddon;
}

/*
<globals>
	dumpVal

	weakref
	deref

	allFieldsOf
	fieldsOf
	findField
	hasField
	hasMethod
	rawGetField
	rawSetField

	isSet
	findGlobal

	typeof
	isArray
	isBool
	isChar
	isClass
	isFloat
	isFuncDef
	isFunction
	isInstance
	isInt
	isMemblock
	isNamespace
	isNativeObj
	isNull
	isString
	isTable
	isThread
	isWeakRef

	nameOf

	format
	rawToString
	toBool
	toChar
	toFloat
	toInt
	toString


docs
	_doc_
	docsOf
	processDocs
	BaseDocOutput
	TracWikiDocOutput
	HtmlDocOutput
	LatexDocOutput?
stream
text
	TextCodec
	registerCodec
	getCodec
	hasCodec
time
	Timer
	compare
	culture
	dateString
	dateTime
	microTime
	sleep
	timestamp
	timex
*/

void main()
{
	scope(exit) Stdout.flush;

	CrocVM vm;
	CrocThread* t;

	try
	{
		t = openVM(&vm);
		loadUnsafeLibs(t, CrocUnsafeLib.ReallyAll);

		version(CrocPcreAddon) PcreLib.init(t);
		version(CrocSdlAddon) SdlLib.init(t);
		version(CrocGlAddon) GlLib.init(t);
		version(CrocNetAddon) NetLib.init(t);
		version(CrocDevilAddon) DevilLib.init(t);

		newFunction(t, &processComment_wrap, "processComment");
		newGlobal(t, "processComment");

		Compiler.setDefaultFlags(t, Compiler.All | Compiler.DocDecorators);
		runModule(t, "samples.simple");
	}
	catch(CrocException e)
	{
		t = t ? t : mainThread(&vm); // in case, while fucking around, we manage to throw an exception from openVM
		catchException(t);
		Stdout.formatln("{}", e);

		dup(t);
		pushNull(t);
		methodCall(t, -2, "tracebackString", 1);
		Stdout.formatln("{}", getString(t, -1));

		pop(t, 2);

		if(e.info)
		{
			Stdout("\nD Traceback: ").newline;
			e.info.writeOut((char[]s) { Stdout(s); });
		}
	}
	catch(CrocHaltException e)
		Stdout.formatln("Thread halted");
	catch(Exception e)
	{
		Stdout("Bad error:").newline;
		e.writeOut((char[]s) { Stdout(s); });
		return;
	}

	closeVM(&vm);
}
