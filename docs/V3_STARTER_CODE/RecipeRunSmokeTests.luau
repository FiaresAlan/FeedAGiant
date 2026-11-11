--!strict
-- Testes de fumaça EXEMPLARES. Ajuste requires à árvore do projeto.
-- NÃO são evidência de compilação ou Studio QA até serem executados.
local RecipeCatalog = require(script.Parent.RecipeCatalogV3)
local RunRules = require(script.Parent.ElementRunRulesV3)

assert(RecipeCatalog.findPair("apple","bread").id == "toast_apple")
assert(RecipeCatalog.findPair("bread","apple").id == "toast_apple")
assert(RecipeCatalog.findPair("apple","meat") == nil)
assert(RecipeCatalog.getById("spicy_meat").duration == 720)
assert(#RecipeCatalog.all() == 6)

local stoneHeavy = RunRules.speed({element="stone",weightClass="heavy",progressionMultiplier=1,sprinting=false,boostActive=true})
local stoneNoBoost = RunRules.speed({element="stone",weightClass="heavy",progressionMultiplier=1,sprinting=false,boostActive=false})
assert(stoneHeavy ~= nil and stoneNoBoost ~= nil)
assert(stoneHeavy > stoneNoBoost)
assert(RunRules.speed({element="evil",weightClass="light",progressionMultiplier=1,sprinting=false,boostActive=false}) == nil)
assert(RunRules.countersInterrupt("ice",true,false) == true)
assert(RunRules.countersInterrupt("ice",true,true) == false)
print("V3 pure rule examples passed")
