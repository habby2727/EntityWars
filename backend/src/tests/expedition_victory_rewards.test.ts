import { expect, test } from "bun:test";
import { expeditionVictoryTier, expeditionVictoryGrants } from "../expeditions_service";
import { expeditionDraw } from "../expeditions_rules";

test("depth and capturable threat have stable bounded tier thresholds", () => {
  const normal = {capturable:false}, capture = {capturable:true};
  for (const [depth, expected] of [[1,"normal"],[4,"normal"],[5,"difficult"],[14,"difficult"],[15,"very_difficult"],[34,"very_difficult"],[35,"exceptional"]] as const)
    expect(expeditionVictoryTier(depth,normal,{})).toBe(expected);
  for (const [depth, expected] of [[1,"normal"],[3,"normal"],[4,"difficult"],[11,"difficult"],[12,"very_difficult"],[29,"very_difficult"],[30,"exceptional"]] as const)
    expect(expeditionVictoryTier(depth,capture,{})).toBe(expected);
  expect(expeditionVictoryTier(10,{...normal,hp:1,attack:1,defense:1},{})).toBe(expeditionVictoryTier(10,{...normal,hp:999,attack:999,defense:999},{}));
});
test("exclusive victory bonus has deterministic 8/2/90 boundaries", () => {
  expect(expeditionVictoryGrants("normal",0)).toEqual({essence:30,arcane_shard:1});
  expect(expeditionVictoryGrants("difficult",0.08)).toEqual({essence:45,core:1,time_crystal:1});
  expect(expeditionVictoryGrants("very_difficult",0.10)).toEqual({essence:60,core:1});
  expect(expeditionVictoryGrants("exceptional",0.99)).toEqual({essence:90,core:2});
  const seed=new Uint8Array(32).fill(12), key=JSON.stringify(["victory-loot","run",3]);
  expect(expeditionDraw(seed,key,0)).toBe(expeditionDraw(seed,key,0));
});
