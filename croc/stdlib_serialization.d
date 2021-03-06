/******************************************************************************
This module contains the Croc interface to the serialization framework.

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

module croc.stdlib_serialization;

import tango.io.model.IConduit;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.serialization;
import croc.stdlib_stream;
import croc.types;

// ================================================================================================================================================
// Public
// ================================================================================================================================================

public:

struct SerializationLib
{
static:
	void init(CrocThread* t)
	{
		makeModule(t, "serialization", function uword(CrocThread* t)
		{
			importModuleNoNS(t, "stream");

			newFunction(t, 3, &serializeGraph,   "serializeGraph");   newGlobal(t, "serializeGraph");
			newFunction(t, 2, &deserializeGraph, "deserializeGraph"); newGlobal(t, "deserializeGraph");
			return 0;
		});
		
		importModuleNoNS(t, "serialization");
	}

	uword serializeGraph(CrocThread* t)
	{
		checkAnyParam(t, 1);
		checkParam(t, 2, CrocValue.Type.Table);
		checkAnyParam(t, 3);

		lookup(t, "stream.OutStream");
		OutputStream stream;

		if(as(t, 3, -1))
		{
			pop(t);
			stream = OutStreamObj.getOpenStream(t, 3);
		}
		else
		{
			pop(t);
			lookup(t, "stream.InoutStream");

			if(as(t, 3, -1))
			{
				pop(t);
				stream = InoutStreamObj.getOpenStream(t, 3);
			}
			else
				paramTypeError(t, 3, "stream.OutStream|stream.InoutStream");
		}

		.serializeGraph(t, 1, 2, stream);
		return 0;
	}

	uword deserializeGraph(CrocThread* t)
	{
		checkParam(t, 1, CrocValue.Type.Table);
		checkAnyParam(t, 2);

		lookup(t, "stream.InStream");
		InputStream stream;

		if(as(t, 2, -1))
		{
			pop(t);
			stream = InStreamObj.getOpenStream(t, 2);
		}
		else
		{
			pop(t);
			lookup(t, "stream.InoutStream");

			if(as(t, 2, -1))
			{
				pop(t);
				stream = InoutStreamObj.getOpenStream(t, 2);
			}
			else
				paramTypeError(t, 2, "stream.OutStream|stream.InoutStream");
		}

		.deserializeGraph(t, 1, stream);
		return 1;
	}
}