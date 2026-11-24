/** A protected start ends the viewer's in-memory observation before commit. */
let viewerNames: ((player:string)=>string[]) | undefined;
let endViewer: (player:string)=>void = () => {};
export function installSpectatorStartGuard(callback:(player:string)=>void, names:(player:string)=>string[]) { endViewer=callback; viewerNames=names; }
export function spectatorNames(player:string): {spectators:string[]} | {} { return viewerNames ? {spectators:viewerNames(player)} : {}; }
export function endSpectatingForStart(player:string) { endViewer(player); }
