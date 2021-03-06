/******************************************************************************
This module contains the Croc standard library module that provides access to
the Croc compiler.

License:
Copyright (c) 2011 Jarrett Billingsley

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the
use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it freely,
subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software in a
	product, an acknowledgment in the product documentation would be
	appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not
	be misrepresented as being the original software.

    3. This notice may not be removed or altered from any source distribution.
******************************************************************************/

module croc.stdlib_compiler;

import croc.api_interpreter;
import croc.api_stack;
import croc.compiler;
import croc.ex;
import croc.types;

struct CompilerLib
{
static:
	void init(CrocThread* t)
	{
		makeModule(t, "compiler", function uword(CrocThread* t)
		{
			newFunction(t, 3, &loadString, "loadString");       newGlobal(t, "loadString");
			newFunction(t, 2, &eval, "eval");                   newGlobal(t, "eval");
			newFunction(t, 2, &compileModule, "compileModule"); newGlobal(t, "compileModule");

			return 0;
		});

		importModuleNoNS(t, "compiler");
	}
	
	uword loadString(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto code = checkStringParam(t, 1);
		char[] name = "<loaded by loadString>";

		if(numParams > 1)
		{
			if(isString(t, 2))
			{
				name = getString(t, 2);

				if(numParams > 2)
				{
					checkParam(t, 3, CrocValue.Type.Namespace);
					dup(t, 3);
				}
				else
					pushEnvironment(t, 1);
			}
			else
			{
				checkParam(t, 2, CrocValue.Type.Namespace);
				dup(t, 2);
			}
		}
		else
			pushEnvironment(t, 1);

		scope c = new Compiler(t);
		c.compileStatements(code, name);
		swap(t);
		newFunctionWithEnv(t, -2);
		return 1;
	}

	uword eval(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto code = checkStringParam(t, 1);
		scope c = new Compiler(t);
		c.compileExpression(code, "<loaded by eval>");

		if(numParams > 1)
		{
			checkParam(t, 2, CrocValue.Type.Namespace);
			dup(t, 2);
		}
		else
			pushEnvironment(t, 1);

		newFunctionWithEnv(t, -2);
		pushNull(t);
		return rawCall(t, -2, -1);
	}

	uword compileModule(CrocThread* t)
	{
		auto src = checkStringParam(t, 1);
		auto name = optStringParam(t, 2, "<loaded by compiler.compileModule>");
		auto ssize = stackSize(t);
		scope c = new Compiler(t);
		char[] modName = void;
		c.compileModule(src, name, modName);
		pushString(t, modName);
		return stackSize(t) - ssize;
	}
}