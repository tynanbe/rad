'use strict';

let toml = `
[a.b] #

c.d = { e.f = 0.0 } #
`;

let TOML=$('TOML',()=>require('.'));
let parsed=$('TOML.parse',()=>TOML.parse(toml,'',true,{comment:true}));
let stringified=$('TOML.stringify',()=>TOML.stringify(parsed,{newline:'\n'}));
stringified===toml||$('TOML.stringify');

function $(msg,fn){try{return fn();}catch{throw Error(`@ltd/j-toml/package.json#scripts.test -- ${msg}`);}}
