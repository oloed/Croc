/******************************************************************************
This module contains the 'math' standard library.

License:
Copyright (c) 2008 Jarrett Billingsley

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

module croc.stdlib_math;

import tango.math.GammaFunction;
import tango.math.IEEE;
import tango.math.Math;
import tango.math.random.Kiss;

alias tango.math.IEEE.isInfinity ieee_isInfinity;
alias tango.math.IEEE.isNaN ieee_isNaN;
alias tango.math.Math.abs math_abs;
alias tango.math.Math.acos math_acos;
alias tango.math.Math.asin math_asin;
alias tango.math.Math.atan math_atan;
alias tango.math.Math.atan2 math_atan2;
alias tango.math.Math.cbrt math_cbrt;
alias tango.math.Math.ceil math_ceil;
alias tango.math.Math.cos math_cos;
alias tango.math.Math.E math_E;
alias tango.math.Math.exp math_exp;
alias tango.math.Math.floor math_floor;
alias tango.math.Math.hypot math_hypot;
alias tango.math.Math.log math_log;
alias tango.math.Math.log10 math_log10;
alias tango.math.Math.log2 math_log2;
alias tango.math.Math.PI math_PI;
alias tango.math.Math.pow math_pow;
alias tango.math.Math.round math_round;
alias tango.math.Math.sin math_sin;
alias tango.math.Math.sqrt math_sqrt;
alias tango.math.Math.tan math_tan;
alias tango.math.Math.trunc math_trunc;

import croc.api_interpreter;
import croc.api_stack;
import croc.ex;
import croc.types;

private void register(CrocThread* t, char[] name, NativeFunc func, uword numUpvals = 0)
{
	newFunction(t, func, name, numUpvals);
	newGlobal(t, name);
}

private void register(CrocThread* t, uword numParams, char[] name, NativeFunc func, uword numUpvals = 0)
{
	newFunction(t, numParams, func, name, numUpvals);
	newGlobal(t, name);
}

struct MathLib
{
static:
	void init(CrocThread* t)
	{
		makeModule(t, "math", function uword(CrocThread* t)
		{
			pushFloat(t, math_E);              newGlobal(t, "e");
			pushFloat(t, math_PI);             newGlobal(t, "pi");
			pushFloat(t, crocfloat.nan);         newGlobal(t, "nan");
			pushFloat(t, crocfloat.infinity);    newGlobal(t, "infinity");

			pushInt(t, crocint.sizeof);          newGlobal(t, "intSize");
			pushInt(t, crocint.min);             newGlobal(t, "intMin");
			pushInt(t, crocint.max);             newGlobal(t, "intMax");

			pushInt(t, crocfloat.sizeof);        newGlobal(t, "floatSize");
			pushFloat(t, crocfloat.min);         newGlobal(t, "floatMin");
			pushFloat(t, crocfloat.max);         newGlobal(t, "floatMax");

			register(t, 1, "abs", &abs);
			register(t, 1, "sin", &sin);
			register(t, 1, "cos", &cos);
			register(t, 1, "tan", &tan);
			register(t, 1, "asin", &asin);
			register(t, 1, "acos", &acos);
			register(t, 1, "atan", &atan);
			register(t, 2, "atan2", &atan2);
			register(t, 1, "sqrt", &sqrt);
			register(t, 1, "cbrt", &cbrt);
			register(t, 2, "pow", &pow);
			register(t, 1, "exp", &exp);
			register(t, 1, "ln", &ln);
			register(t, 1, "log2", &log2);
			register(t, 1, "log10", &log10);
			register(t, 2, "hypot", &hypot);
			register(t, 1, "lgamma", &lgamma);
			register(t, 1, "gamma", &gamma);
			register(t, 1, "ceil", &ceil);
			register(t, 1, "floor", &floor);
			register(t, 1, "round", &round);
			register(t, 1, "trunc", &trunc);
			register(t, 1, "isNan", &isNan);
			register(t, 1, "isInf", &isInf);
			register(t, 1, "sign", &sign);
			register(t, 2, "rand", &rand);
			register(t, 2, "frand", &frand);
			register(t,    "max", &max);
			register(t,    "min", &min);

			return 0;
		});

		importModuleNoNS(t, "math");
	}

	uword abs(CrocThread* t)
	{
		checkNumParam(t, 1);

		if(isInt(t, 1))
			pushInt(t, math_abs(getInt(t, 1)));
		else
			pushFloat(t, math_abs(getFloat(t, 1)));

		return 1;
	}

	uword sin(CrocThread* t)
	{
		pushFloat(t, math_sin(checkNumParam(t, 1)));
		return 1;
	}

	uword cos(CrocThread* t)
	{
		pushFloat(t, math_cos(checkNumParam(t, 1)));
		return 1;
	}

	uword tan(CrocThread* t)
	{
		pushFloat(t, math_tan(checkNumParam(t, 1)));
		return 1;
	}

	uword asin(CrocThread* t)
	{
		pushFloat(t, math_asin(checkNumParam(t, 1)));
		return 1;
	}

	uword acos(CrocThread* t)
	{
		pushFloat(t, math_acos(checkNumParam(t, 1)));
		return 1;
	}

	uword atan(CrocThread* t)
	{
		pushFloat(t, math_atan(checkNumParam(t, 1)));
		return 1;
	}

	uword atan2(CrocThread* t)
	{
		pushFloat(t, math_atan2(checkNumParam(t, 1), checkNumParam(t, 2)));
		return 1;
	}

	uword sqrt(CrocThread* t)
	{
		pushFloat(t, math_sqrt(checkNumParam(t, 1)));
		return 1;
	}

	uword cbrt(CrocThread* t)
	{
		pushFloat(t, math_cbrt(checkNumParam(t, 1)));
		return 1;
	}

	uword pow(CrocThread* t)
	{
		auto base = checkNumParam(t, 1);
		auto exp = checkNumParam(t, 2);

		if(isInt(t, 2))
			pushFloat(t, math_pow(cast(real)base, cast(uint)getInt(t, 2)));
		else
			pushFloat(t, math_pow(base, exp));

		return 1;
	}

	uword exp(CrocThread* t)
	{
		pushFloat(t, math_exp(checkNumParam(t, 1)));
		return 1;
	}

	uword ln(CrocThread* t)
	{
		pushFloat(t, math_log(checkNumParam(t, 1)));
		return 1;
	}

	uword log2(CrocThread* t)
	{
		pushFloat(t, math_log2(checkNumParam(t, 1)));
		return 1;
	}

	uword log10(CrocThread* t)
	{
		pushFloat(t, math_log10(checkNumParam(t, 1)));
		return 1;
	}

	uword hypot(CrocThread* t)
	{
		pushFloat(t, math_hypot(checkNumParam(t, 1), checkNumParam(t, 2)));
		return 1;
	}

	uword lgamma(CrocThread* t)
	{
		pushFloat(t, logGamma(checkNumParam(t, 1)));
		return 1;
	}

	uword gamma(CrocThread* t)
	{
		pushFloat(t, .gamma(checkNumParam(t, 1)));
		return 1;
	}

	uword ceil(CrocThread* t)
	{
		pushFloat(t, math_ceil(checkNumParam(t, 1)));
		return 1;
	}

	uword floor(CrocThread* t)
	{
		pushFloat(t, math_floor(checkNumParam(t, 1)));
		return 1;
	}

	uword round(CrocThread* t)
	{
		pushInt(t, cast(crocint)math_round(checkNumParam(t, 1)));
		return 1;
	}

	uword trunc(CrocThread* t)
	{
		pushInt(t, cast(crocint)math_trunc(checkNumParam(t, 1)));
		return 1;
	}

	uword isNan(CrocThread* t)
	{
		pushBool(t, cast(bool)ieee_isNaN(checkNumParam(t, 1)));
		return 1;
	}

	uword isInf(CrocThread* t)
	{
		pushBool(t, cast(bool)ieee_isInfinity(checkNumParam(t, 1)));
		return 1;
	}

	uword sign(CrocThread* t)
	{
		checkNumParam(t, 1);

		if(isInt(t, 1))
		{
			auto val = getInt(t, 1);

			if(val < 0)
				pushInt(t, -1);
			else if(val > 0)
				pushInt(t, 1);
			else
				pushInt(t, 0);
		}
		else
		{
			auto val = getFloat(t, 1);

			if(val < 0)
				pushInt(t, -1);
			else if(val > 0)
				pushInt(t, 1);
			else
				pushInt(t, 0);
		}

		return 1;
	}

	uword rand(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		// uint is the return type of Kiss.toInt
		static if(uint.sizeof < crocint.sizeof)
		{
			crocint num = Kiss.instance.toInt();
			num |= (cast(ulong)Kiss.instance.toInt()) << 32;
		}
		else
			crocint num = Kiss.instance.toInt();

		switch(numParams)
		{
			case 0:
				pushInt(t, num);
				break;

			case 1:
				auto max = checkIntParam(t, 1);

				if(max == 0)
					throwStdException(t, "RangeException", "Maximum value may not be 0");

				pushInt(t, cast(uword)num % max);
				break;

			default:
				auto lo = checkIntParam(t, 1);
				auto hi = checkIntParam(t, 2);

				if(hi == lo)
					throwStdException(t, "ValueException", "Low and high values must be different");

				pushInt(t, (cast(uword)num % (hi - lo)) + lo);
				break;
		}

		return 1;
	}

	uword frand(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		auto num = cast(crocfloat)Kiss.instance.toInt() / uint.max;

		switch(numParams)
		{
			case 0:
				pushFloat(t, num);
				break;

			case 1:
				pushFloat(t, num * checkNumParam(t, 1));
				break;

			default:
				auto lo = checkNumParam(t, 1);
				auto hi = checkNumParam(t, 2);

				pushFloat(t, (num * (hi - lo)) + lo);
				break;
		}

		return 1;
	}

	uword max(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		switch(numParams)
		{
			case 0:
				throwStdException(t, "ParamException", "At least one parameter required");

			case 1:
				break;

			case 2:
				if(cmp(t, 1, 2) > 0)
					pop(t);
				break;

			default:
				word m = 1;

				for(uword i = 2; i <= numParams; i++)
					if(cmp(t, i, m) > 0)
						m = i;

				dup(t, m);
				break;
		}

		return 1;
	}

	uword min(CrocThread* t)
	{
		auto numParams = stackSize(t) - 1;
		switch(numParams)
		{
			case 0:
				throwStdException(t, "ParamException", "At least one parameter required");

			case 1:
				break;

			case 2:
				if(cmp(t, 1, 2) < 0)
					pop(t);
				break;

			default:
				word m = 1;

				for(uword i = 2; i <= numParams; i++)
					if(cmp(t, i, m) < 0)
						m = i;

				dup(t, m);
				break;
		}


		return 1;
	}
}