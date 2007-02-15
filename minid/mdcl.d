module minid.mdcl;

import minid.compiler;
import minid.minid;
import minid.types;

import std.cstream;
import std.path;
import std.stdio;
import std.stream;

void printVersion()
{
	writefln("MiniD Command-Line interpreter beta");
}

void printUsage()
{
	printVersion();
	writefln("Usage:");
	writefln("\tmdcl [flags] [filename [args]]");
	writefln();
	writefln("Flags:");
	writefln("\t-i   Enter interactive mode, after executing any script file.");
	writefln("\t-v   Print the version of the CLI.");
	writefln("\t-h   Print this message and end.");
	writefln();
	writefln("If mdcl is called without any arguments, it will be as if you passed it");
	writefln("the -v and -i arguments (it will print the version and enter interactive");
	writefln("mode).");
	writefln();
	writefln("When passing a filename followed by args, all the args will be available");
	writefln("to the script by using the vararg expression.  The arguments will all be");
	writefln("strings.");
	writefln();
	writefln("In interactive mode, you will be given a >>> prompt.  When you hit enter,");
	writefln("you may be given a ... prompt.  That means you need to type more to make");
	writefln("the code complete.  Once you enter enough code to make it complete, the");
	writefln("code will be run.  If there is an error, the code buffer is cleared.");
	writefln("To end interactive mode, type the end-of-file character (Ctrl-Z on DOS,");
	writefln("Ctrl-D on *nix) and hit enter to end, or force exit by hitting Ctrl-C.");
}

const char[] Prompt1 = ">>> ";
const char[] Prompt2 = "... ";

void main(char[][] args)
{
	bool printedVersion = false;
	bool interactive = false;
	char[] inputFile;
	char[][] scriptArgs;

	if(args.length == 1)
	{
		printVersion();
		interactive = true;
	}

	_argLoop: for(int i = 1; i < args.length; i++)
	{
		switch(args[i])
		{
			case "-i":
				interactive = true;
				break;

			case "-v":
				if(printedVersion == false)
				{
					printedVersion = true;
					printVersion();
				}
				break;
				
			case "-h":
				printUsage();
				return;

			default:
				if(args[i][0] == '-')
				{
					writefln("Invalid flag '%s'", args[i]);
					printUsage();
					return;
				}

				inputFile = args[i];
				scriptArgs = args[i + 1 .. $];
				break _argLoop;
		}
	}
	
	MDState state = MDInitialize();

	if(inputFile.length > 0)
	{
		MDModuleDef def;

		if(inputFile.length >= 3 && inputFile[$ - 3 .. $] == ".md")
			def = compileModule(inputFile);
		else if(inputFile.length >= 4 && inputFile[$ - 4 .. $] == ".mdm")
			def = MDModuleDef.loadFromFile(inputFile);

		uint funcReg = state.push(MDGlobalState().initModule(def, false, state));

		foreach(arg; scriptArgs)
			state.push(arg);

		state.call(funcReg, scriptArgs.length, 0);
	}

	if(interactive)
	{
		writefln("Type EOF (Ctrl-D on *nix, Ctrl-Z on Windows) and hit enter to end.");

		char[] buffer;

		writef(Prompt1);

		while(true)
		{
			char[] line = din.readLine();

			if(din.eof())
				break;

			buffer ~= line;

			scope MemoryStream s = new MemoryStream(buffer);

			bool atEOF = false;
			MDFuncDef def;

			try
			{
				def = compileStatement(s, "stdin", atEOF);
			}
			catch(MDCompileException e)
			{
				if(atEOF)
				{
					writef(Prompt2);
				}
				else
				{
					writefln(e);
					writefln();
					writef(Prompt1);
					buffer.length = 0;
				}

				continue;
			}

			try
			{
				scope closure = MDGlobalState().newClosure(def);
				state.easyCall(closure, 0);
			}
			catch(MDException e)
			{
				writefln(e);
				writefln();
			}

			writef(Prompt1);
			buffer.length = 0;
		}
	}
}