// -------------------------------------------------------------------------
// 头文件保护 (Include Guard / 宏卫哨) 机制
// 核心作用：防止该头文件被多个 `.v` 文件 `include` 时产生“宏重复定义”的编译器报错。
// 套路格式：
// `ifndef 标签
//      `define 标签      
//      这里写各种具体的宏定义...  
// `endif

// -------------------------------------------------------------------------
// 如果之前“没有定义过(If Not Defined)” OPCODE_VH 这个宏标签...
`ifndef OPCODE_VH
// ...那么现在立刻定义它。这样当其他文件再次 include 此文件时，编译器就会直接跳过里面的内容。
// 这同样是整个编程界（从 C 语言时代传下来的）的一种强制潜规则（命名规约）。 
// 在 Verilog 和 C/C++ 中，普通的变量名、模块名一般用小写或者驼峰命名法（如 instruction, Decoder）。 
// 而所有的宏定义（被 `define 定义出来的东西），无论是这种当空标签用的，还是像下面 
// `define OPCODE_LUI 7'b0110111 这种当常量用的，全都必须大写。
`define OPCODE_VH

`define OPCODE_LUI 			7'b0110111
`define OPCODE_AUIPC 		7'b0010111
`define OPCODE_JAL 			7'b1101111
`define OPCODE_JALR 		7'b1100111
`define OPCODE_BRANCH 		7'b1100011
`define OPCODE_LOAD 		7'b0000011
`define OPCODE_STORE 		7'b0100011
`define OPCODE_ITYPE 		7'b0010011
`define OPCODE_RTYPE 		7'b0110011
`define OPCODE_FENCE 		7'b0001111
`define OPCODE_ENVIRONMENT 	7'b1110011

// 结束最上方的 `ifndef 条件判断
`endif // OPCODE_VH