import { expect, test } from "bun:test";
import { expeditionVictoryTier, expeditionVictoryGrants } from "../expeditions_service";
import { expeditionDraw } from "../expeditions_rules";

test("frozen relative threat and depth determine the four bounded tiers", () => {
  const setup={entity:{base_stats:{hp:100,power:100,guard:100}},spells:Array(4).fill({category:"attack",power_mult:1,accuracy:1})};
  const enemy=(ratio:number)=>({hp:100*ratio,attack:100*ratio,defense:100*ratio});
  expect(expeditionVictoryTier(1,enemy(2),setup)).toBe("normal");
  expect(expeditionVictoryTier(2,enemy(1.004),setup)).toBe("normal");
  expect(expeditionVictoryTier(2,enemy(1.006),setup)).toBe("difficult");
  expect(expeditionVictoryTier(4,enemy(1.041),setup)).toBe("very_difficult");
  expect(expeditionVictoryTier(8,enemy(1.081),setup)).toBe("exceptional");
  expect(expeditionVictoryTier(100,enemy(1),setup)).toBe("normal");
});
test("exclusive victory bonus has deterministic 8/2/90 boundaries", () => {
  expect(expeditionVictoryGrants("normal",0)).toEqual({essence:30,arcane_shard:1});
  expect(expeditionVictoryGrants("difficult",0.08)).toEqual({essence:45,core:1,time_crystal:1});
  expect(expeditionVictoryGrants("very_difficult",0.10)).toEqual({essence:60,core:1});
  expect(expeditionVictoryGrants("exceptional",0.99)).toEqual({essence:90,core:2});
  const seed=new Uint8Array(32).fill(12), key=JSON.stringify(["victory-loot","run",3]);
  expect(expeditionDraw(seed,key,0)).toBe(expeditionDraw(seed,key,0));
});
