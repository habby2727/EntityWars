// @bun
var __create = Object.create;
var __getProtoOf = Object.getPrototypeOf;
var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __toESM = (mod, isNodeMode, target) => {
  target = mod != null ? __create(__getProtoOf(mod)) : {};
  const to = isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target;
  for (let key of __getOwnPropNames(mod))
    if (!__hasOwnProp.call(to, key))
      __defProp(to, key, {
        get: () => mod[key],
        enumerable: true
      });
  return to;
};
var __commonJS = (cb, mod) => () => (mod || cb((mod = { exports: {} }).exports, mod), mod.exports);
var __require = import.meta.require;

// node_modules/@ioredis/commands/built/commands.json
var require_commands = __commonJS((exports, module) => {
  module.exports = {
    acl: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    append: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    asking: {
      arity: 1,
      flags: [
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    auth: {
      arity: -2,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "no_auth",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    bgrewriteaof: {
      arity: 1,
      flags: [
        "admin",
        "noscript",
        "no_async_loading"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    bgsave: {
      arity: -1,
      flags: [
        "admin",
        "noscript",
        "no_async_loading"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    bitcount: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    bitfield: {
      arity: -2,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    bitfield_ro: {
      arity: -2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    bitop: {
      arity: -4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 2,
      keyStop: -1,
      step: 1
    },
    bitpos: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    blmove: {
      arity: 6,
      flags: [
        "write",
        "denyoom",
        "noscript",
        "blocking"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    blmpop: {
      arity: -5,
      flags: [
        "write",
        "blocking",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    blpop: {
      arity: -3,
      flags: [
        "write",
        "noscript",
        "blocking"
      ],
      keyStart: 1,
      keyStop: -2,
      step: 1
    },
    brpop: {
      arity: -3,
      flags: [
        "write",
        "noscript",
        "blocking"
      ],
      keyStart: 1,
      keyStop: -2,
      step: 1
    },
    brpoplpush: {
      arity: 4,
      flags: [
        "write",
        "denyoom",
        "noscript",
        "blocking"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    bzmpop: {
      arity: -5,
      flags: [
        "write",
        "blocking",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    bzpopmax: {
      arity: -3,
      flags: [
        "write",
        "noscript",
        "blocking",
        "fast"
      ],
      keyStart: 1,
      keyStop: -2,
      step: 1
    },
    bzpopmin: {
      arity: -3,
      flags: [
        "write",
        "noscript",
        "blocking",
        "fast"
      ],
      keyStart: 1,
      keyStop: -2,
      step: 1
    },
    client: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    cluster: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    command: {
      arity: -1,
      flags: [
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    config: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    copy: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    dbsize: {
      arity: 1,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    debug: {
      arity: -2,
      flags: [
        "admin",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    decr: {
      arity: 2,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    decrby: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    del: {
      arity: -2,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    discard: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    dump: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    echo: {
      arity: 2,
      flags: [
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    eval: {
      arity: -3,
      flags: [
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    eval_ro: {
      arity: -3,
      flags: [
        "readonly",
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    evalsha: {
      arity: -3,
      flags: [
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    evalsha_ro: {
      arity: -3,
      flags: [
        "readonly",
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    exec: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "skip_slowlog"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    exists: {
      arity: -2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    expire: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    expireat: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    expiretime: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    failover: {
      arity: -1,
      flags: [
        "admin",
        "noscript",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    fcall: {
      arity: -3,
      flags: [
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    fcall_ro: {
      arity: -3,
      flags: [
        "readonly",
        "noscript",
        "stale",
        "skip_monitor",
        "no_mandatory_keys",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    flushall: {
      arity: -1,
      flags: [
        "write"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    flushdb: {
      arity: -1,
      flags: [
        "write"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    function: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    geoadd: {
      arity: -5,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    geodist: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    geohash: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    geopos: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    georadius: {
      arity: -6,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    georadius_ro: {
      arity: -6,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    georadiusbymember: {
      arity: -5,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    georadiusbymember_ro: {
      arity: -5,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    geosearch: {
      arity: -7,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    geosearchstore: {
      arity: -8,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    get: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    getbit: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    getdel: {
      arity: 2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    getex: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    getrange: {
      arity: 4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    getset: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hdel: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hello: {
      arity: -1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "no_auth",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    hexists: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hexpire: {
      arity: -6,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hpexpire: {
      arity: -6,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hget: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hgetall: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hincrby: {
      arity: 4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hincrbyfloat: {
      arity: 4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hkeys: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hlen: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hmget: {
      arity: -3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hmset: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hrandfield: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hscan: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hset: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hsetnx: {
      arity: 4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hstrlen: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    hvals: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    incr: {
      arity: 2,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    incrby: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    incrbyfloat: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    info: {
      arity: -1,
      flags: [
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    keys: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    lastsave: {
      arity: 1,
      flags: [
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    latency: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    lcs: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    lindex: {
      arity: 3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    linsert: {
      arity: 5,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    llen: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lmove: {
      arity: 5,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    lmpop: {
      arity: -4,
      flags: [
        "write",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    lolwut: {
      arity: -1,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    lpop: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lpos: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lpush: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lpushx: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lrange: {
      arity: 4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lrem: {
      arity: 4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    lset: {
      arity: 4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    ltrim: {
      arity: 4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    memory: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    mget: {
      arity: -2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    migrate: {
      arity: -6,
      flags: [
        "write",
        "movablekeys"
      ],
      keyStart: 3,
      keyStop: 3,
      step: 1
    },
    module: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    monitor: {
      arity: 1,
      flags: [
        "admin",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    move: {
      arity: 3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    mset: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 2
    },
    msetnx: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 2
    },
    multi: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    object: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    persist: {
      arity: 2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    pexpire: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    pexpireat: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    pexpiretime: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    pfadd: {
      arity: -2,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    pfcount: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    pfdebug: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "admin"
      ],
      keyStart: 2,
      keyStop: 2,
      step: 1
    },
    pfmerge: {
      arity: -2,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    pfselftest: {
      arity: 1,
      flags: [
        "admin"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    ping: {
      arity: -1,
      flags: [
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    psetex: {
      arity: 4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    psubscribe: {
      arity: -2,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    psync: {
      arity: -3,
      flags: [
        "admin",
        "noscript",
        "no_async_loading",
        "no_multi"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    pttl: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    publish: {
      arity: 3,
      flags: [
        "pubsub",
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    pubsub: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    punsubscribe: {
      arity: -1,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    quit: {
      arity: -1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "no_auth",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    randomkey: {
      arity: 1,
      flags: [
        "readonly"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    readonly: {
      arity: 1,
      flags: [
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    readwrite: {
      arity: 1,
      flags: [
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    rename: {
      arity: 3,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    renamenx: {
      arity: 3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    replconf: {
      arity: -1,
      flags: [
        "admin",
        "noscript",
        "loading",
        "stale",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    replicaof: {
      arity: 3,
      flags: [
        "admin",
        "noscript",
        "stale",
        "no_async_loading"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    reset: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "no_auth",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    restore: {
      arity: -4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    "restore-asking": {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "asking"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    role: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    rpop: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    rpoplpush: {
      arity: 3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    rpush: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    rpushx: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    sadd: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    save: {
      arity: 1,
      flags: [
        "admin",
        "noscript",
        "no_async_loading",
        "no_multi"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    scan: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    scard: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    script: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    sdiff: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    sdiffstore: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    select: {
      arity: 2,
      flags: [
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    set: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    setbit: {
      arity: 4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    setex: {
      arity: 4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    setnx: {
      arity: 3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    setrange: {
      arity: 4,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    shutdown: {
      arity: -1,
      flags: [
        "admin",
        "noscript",
        "loading",
        "stale",
        "no_multi",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    sinter: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    sintercard: {
      arity: -3,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    sinterstore: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    sismember: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    slaveof: {
      arity: 3,
      flags: [
        "admin",
        "noscript",
        "stale",
        "no_async_loading"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    slowlog: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    smembers: {
      arity: 2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    smismember: {
      arity: -3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    smove: {
      arity: 4,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    sort: {
      arity: -2,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    sort_ro: {
      arity: -2,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    spop: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    spublish: {
      arity: 3,
      flags: [
        "pubsub",
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    srandmember: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    srem: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    sscan: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    ssubscribe: {
      arity: -2,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    strlen: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    subscribe: {
      arity: -2,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    substr: {
      arity: 4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    sunion: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    sunionstore: {
      arity: -3,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    sunsubscribe: {
      arity: -1,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    swapdb: {
      arity: 3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    sync: {
      arity: 1,
      flags: [
        "admin",
        "noscript",
        "no_async_loading",
        "no_multi"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    time: {
      arity: 1,
      flags: [
        "loading",
        "stale",
        "fast"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    touch: {
      arity: -2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    ttl: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    type: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    unlink: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    unsubscribe: {
      arity: -1,
      flags: [
        "pubsub",
        "noscript",
        "loading",
        "stale"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    unwatch: {
      arity: 1,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "allow_busy"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    wait: {
      arity: 3,
      flags: [
        "noscript"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    watch: {
      arity: -2,
      flags: [
        "noscript",
        "loading",
        "stale",
        "fast",
        "allow_busy"
      ],
      keyStart: 1,
      keyStop: -1,
      step: 1
    },
    xack: {
      arity: -4,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xadd: {
      arity: -5,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xautoclaim: {
      arity: -6,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xclaim: {
      arity: -6,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xdel: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xdelex: {
      arity: -5,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xgroup: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    xinfo: {
      arity: -2,
      flags: [],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    xlen: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xpending: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xrange: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xread: {
      arity: -4,
      flags: [
        "readonly",
        "blocking",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    xreadgroup: {
      arity: -7,
      flags: [
        "write",
        "blocking",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    xrevrange: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xsetid: {
      arity: -3,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    xtrim: {
      arity: -4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zadd: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zcard: {
      arity: 2,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zcount: {
      arity: 4,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zdiff: {
      arity: -3,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    zdiffstore: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zincrby: {
      arity: 4,
      flags: [
        "write",
        "denyoom",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zinter: {
      arity: -3,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    zintercard: {
      arity: -3,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    zinterstore: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zlexcount: {
      arity: 4,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zmpop: {
      arity: -4,
      flags: [
        "write",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    zmscore: {
      arity: -3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zpopmax: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zpopmin: {
      arity: -2,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrandmember: {
      arity: -2,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrange: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrangebylex: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrangebyscore: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrangestore: {
      arity: -5,
      flags: [
        "write",
        "denyoom"
      ],
      keyStart: 1,
      keyStop: 2,
      step: 1
    },
    zrank: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrem: {
      arity: -3,
      flags: [
        "write",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zremrangebylex: {
      arity: 4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zremrangebyrank: {
      arity: 4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zremrangebyscore: {
      arity: 4,
      flags: [
        "write"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrevrange: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrevrangebylex: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrevrangebyscore: {
      arity: -4,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zrevrank: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zscan: {
      arity: -3,
      flags: [
        "readonly"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zscore: {
      arity: 3,
      flags: [
        "readonly",
        "fast"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    },
    zunion: {
      arity: -3,
      flags: [
        "readonly",
        "movablekeys"
      ],
      keyStart: 0,
      keyStop: 0,
      step: 0
    },
    zunionstore: {
      arity: -4,
      flags: [
        "write",
        "denyoom",
        "movablekeys"
      ],
      keyStart: 1,
      keyStop: 1,
      step: 1
    }
  };
});

// node_modules/@ioredis/commands/built/index.js
var require_built = __commonJS((exports) => {
  var __importDefault = exports && exports.__importDefault || function(mod) {
    return mod && mod.__esModule ? mod : { default: mod };
  };
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.getKeyIndexes = exports.hasFlag = exports.exists = exports.list = undefined;
  var commands_json_1 = __importDefault(require_commands());
  exports.list = Object.keys(commands_json_1.default);
  var flags = {};
  exports.list.forEach((commandName) => {
    flags[commandName] = commands_json_1.default[commandName].flags.reduce(function(flags2, flag) {
      flags2[flag] = true;
      return flags2;
    }, {});
  });
  function exists(commandName, options) {
    commandName = (options === null || options === undefined ? undefined : options.caseInsensitive) ? String(commandName).toLowerCase() : commandName;
    return Boolean(commands_json_1.default[commandName]);
  }
  exports.exists = exists;
  function hasFlag(commandName, flag, options) {
    commandName = (options === null || options === undefined ? undefined : options.nameCaseInsensitive) ? String(commandName).toLowerCase() : commandName;
    if (!flags[commandName]) {
      throw new Error("Unknown command " + commandName);
    }
    return Boolean(flags[commandName][flag]);
  }
  exports.hasFlag = hasFlag;
  function getKeyIndexes(commandName, args, options) {
    commandName = (options === null || options === undefined ? undefined : options.nameCaseInsensitive) ? String(commandName).toLowerCase() : commandName;
    const command = commands_json_1.default[commandName];
    if (!command) {
      throw new Error("Unknown command " + commandName);
    }
    if (!Array.isArray(args)) {
      throw new Error("Expect args to be an array");
    }
    const keys = [];
    const parseExternalKey = Boolean(options && options.parseExternalKey);
    const takeDynamicKeys = (args2, startIndex) => {
      const keys2 = [];
      const keyStop = Number(args2[startIndex]);
      for (let i = 0;i < keyStop; i++) {
        keys2.push(i + startIndex + 1);
      }
      return keys2;
    };
    const takeKeyAfterToken = (args2, startIndex, token) => {
      for (let i = startIndex;i < args2.length - 1; i += 1) {
        if (String(args2[i]).toLowerCase() === token.toLowerCase()) {
          return i + 1;
        }
      }
      return null;
    };
    switch (commandName) {
      case "zunionstore":
      case "zinterstore":
      case "zdiffstore":
        keys.push(0, ...takeDynamicKeys(args, 1));
        break;
      case "eval":
      case "evalsha":
      case "eval_ro":
      case "evalsha_ro":
      case "fcall":
      case "fcall_ro":
      case "blmpop":
      case "bzmpop":
        keys.push(...takeDynamicKeys(args, 1));
        break;
      case "sintercard":
      case "lmpop":
      case "zunion":
      case "zinter":
      case "zmpop":
      case "zintercard":
      case "zdiff": {
        keys.push(...takeDynamicKeys(args, 0));
        break;
      }
      case "georadius": {
        keys.push(0);
        const storeKey = takeKeyAfterToken(args, 5, "STORE");
        if (storeKey)
          keys.push(storeKey);
        const distKey = takeKeyAfterToken(args, 5, "STOREDIST");
        if (distKey)
          keys.push(distKey);
        break;
      }
      case "georadiusbymember": {
        keys.push(0);
        const storeKey = takeKeyAfterToken(args, 4, "STORE");
        if (storeKey)
          keys.push(storeKey);
        const distKey = takeKeyAfterToken(args, 4, "STOREDIST");
        if (distKey)
          keys.push(distKey);
        break;
      }
      case "sort":
      case "sort_ro":
        keys.push(0);
        for (let i = 1;i < args.length - 1; i++) {
          let arg = args[i];
          if (typeof arg !== "string") {
            continue;
          }
          const directive = arg.toUpperCase();
          if (directive === "GET") {
            i += 1;
            arg = args[i];
            if (arg !== "#") {
              if (parseExternalKey) {
                keys.push([i, getExternalKeyNameLength(arg)]);
              } else {
                keys.push(i);
              }
            }
          } else if (directive === "BY") {
            i += 1;
            if (parseExternalKey) {
              keys.push([i, getExternalKeyNameLength(args[i])]);
            } else {
              keys.push(i);
            }
          } else if (directive === "STORE") {
            i += 1;
            keys.push(i);
          }
        }
        break;
      case "migrate":
        if (args[2] === "") {
          for (let i = 5;i < args.length - 1; i++) {
            const arg = args[i];
            if (typeof arg === "string" && arg.toUpperCase() === "KEYS") {
              for (let j = i + 1;j < args.length; j++) {
                keys.push(j);
              }
              break;
            }
          }
        } else {
          keys.push(2);
        }
        break;
      case "xreadgroup":
      case "xread":
        for (let i = commandName === "xread" ? 0 : 3;i < args.length - 1; i++) {
          if (String(args[i]).toUpperCase() === "STREAMS") {
            for (let j = i + 1;j <= i + (args.length - 1 - i) / 2; j++) {
              keys.push(j);
            }
            break;
          }
        }
        break;
      default:
        if (command.step > 0) {
          const keyStart = command.keyStart - 1;
          const keyStop = command.keyStop > 0 ? command.keyStop : args.length + command.keyStop + 1;
          for (let i = keyStart;i < keyStop; i += command.step) {
            keys.push(i);
          }
        }
        break;
    }
    return keys;
  }
  exports.getKeyIndexes = getKeyIndexes;
  function getExternalKeyNameLength(key) {
    if (typeof key !== "string") {
      key = String(key);
    }
    const hashPos = key.indexOf("->");
    return hashPos === -1 ? key.length : hashPos;
  }
});

// node_modules/standard-as-callback/built/utils.js
var require_utils = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.tryCatch = exports.errorObj = undefined;
  exports.errorObj = { e: {} };
  var tryCatchTarget;
  function tryCatcher(err, val) {
    try {
      const target = tryCatchTarget;
      tryCatchTarget = null;
      return target.apply(this, arguments);
    } catch (e) {
      exports.errorObj.e = e;
      return exports.errorObj;
    }
  }
  function tryCatch(fn) {
    tryCatchTarget = fn;
    return tryCatcher;
  }
  exports.tryCatch = tryCatch;
});

// node_modules/standard-as-callback/built/index.js
var require_built2 = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var utils_1 = require_utils();
  function throwLater(e) {
    setTimeout(function() {
      throw e;
    }, 0);
  }
  function asCallback(promise, nodeback, options) {
    if (typeof nodeback === "function") {
      promise.then((val) => {
        let ret;
        if (options !== undefined && Object(options).spread && Array.isArray(val)) {
          ret = utils_1.tryCatch(nodeback).apply(undefined, [null].concat(val));
        } else {
          ret = val === undefined ? utils_1.tryCatch(nodeback)(null) : utils_1.tryCatch(nodeback)(null, val);
        }
        if (ret === utils_1.errorObj) {
          throwLater(ret.e);
        }
      }, (cause) => {
        if (!cause) {
          const newReason = new Error(cause + "");
          Object.assign(newReason, { cause });
          cause = newReason;
        }
        const ret = utils_1.tryCatch(nodeback)(cause);
        if (ret === utils_1.errorObj) {
          throwLater(ret.e);
        }
      });
    }
    return promise;
  }
  exports.default = asCallback;
});

// node_modules/redis-errors/lib/old.js
var require_old = __commonJS((exports, module) => {
  var assert = __require("assert");
  var util = __require("util");
  function RedisError(message) {
    Object.defineProperty(this, "message", {
      value: message || "",
      configurable: true,
      writable: true
    });
    Error.captureStackTrace(this, this.constructor);
  }
  util.inherits(RedisError, Error);
  Object.defineProperty(RedisError.prototype, "name", {
    value: "RedisError",
    configurable: true,
    writable: true
  });
  function ParserError(message, buffer, offset) {
    assert(buffer);
    assert.strictEqual(typeof offset, "number");
    Object.defineProperty(this, "message", {
      value: message || "",
      configurable: true,
      writable: true
    });
    const tmp = Error.stackTraceLimit;
    Error.stackTraceLimit = 2;
    Error.captureStackTrace(this, this.constructor);
    Error.stackTraceLimit = tmp;
    this.offset = offset;
    this.buffer = buffer;
  }
  util.inherits(ParserError, RedisError);
  Object.defineProperty(ParserError.prototype, "name", {
    value: "ParserError",
    configurable: true,
    writable: true
  });
  function ReplyError(message) {
    Object.defineProperty(this, "message", {
      value: message || "",
      configurable: true,
      writable: true
    });
    const tmp = Error.stackTraceLimit;
    Error.stackTraceLimit = 2;
    Error.captureStackTrace(this, this.constructor);
    Error.stackTraceLimit = tmp;
  }
  util.inherits(ReplyError, RedisError);
  Object.defineProperty(ReplyError.prototype, "name", {
    value: "ReplyError",
    configurable: true,
    writable: true
  });
  function AbortError(message) {
    Object.defineProperty(this, "message", {
      value: message || "",
      configurable: true,
      writable: true
    });
    Error.captureStackTrace(this, this.constructor);
  }
  util.inherits(AbortError, RedisError);
  Object.defineProperty(AbortError.prototype, "name", {
    value: "AbortError",
    configurable: true,
    writable: true
  });
  function InterruptError(message) {
    Object.defineProperty(this, "message", {
      value: message || "",
      configurable: true,
      writable: true
    });
    Error.captureStackTrace(this, this.constructor);
  }
  util.inherits(InterruptError, AbortError);
  Object.defineProperty(InterruptError.prototype, "name", {
    value: "InterruptError",
    configurable: true,
    writable: true
  });
  module.exports = {
    RedisError,
    ParserError,
    ReplyError,
    AbortError,
    InterruptError
  };
});

// node_modules/redis-errors/lib/modern.js
var require_modern = __commonJS((exports, module) => {
  var assert = __require("assert");

  class RedisError extends Error {
    get name() {
      return this.constructor.name;
    }
  }

  class ParserError extends RedisError {
    constructor(message, buffer, offset) {
      assert(buffer);
      assert.strictEqual(typeof offset, "number");
      const tmp = Error.stackTraceLimit;
      Error.stackTraceLimit = 2;
      super(message);
      Error.stackTraceLimit = tmp;
      this.offset = offset;
      this.buffer = buffer;
    }
    get name() {
      return this.constructor.name;
    }
  }

  class ReplyError extends RedisError {
    constructor(message) {
      const tmp = Error.stackTraceLimit;
      Error.stackTraceLimit = 2;
      super(message);
      Error.stackTraceLimit = tmp;
    }
    get name() {
      return this.constructor.name;
    }
  }

  class AbortError extends RedisError {
    get name() {
      return this.constructor.name;
    }
  }

  class InterruptError extends AbortError {
    get name() {
      return this.constructor.name;
    }
  }
  module.exports = {
    RedisError,
    ParserError,
    ReplyError,
    AbortError,
    InterruptError
  };
});

// node_modules/redis-errors/index.js
var require_redis_errors = __commonJS((exports, module) => {
  var Errors = process.version.charCodeAt(1) < 55 && process.version.charCodeAt(2) === 46 ? require_old() : require_modern();
  module.exports = Errors;
});

// node_modules/cluster-key-slot/lib/index.js
var require_lib = __commonJS((exports, module) => {
  var lookup = [
    0,
    4129,
    8258,
    12387,
    16516,
    20645,
    24774,
    28903,
    33032,
    37161,
    41290,
    45419,
    49548,
    53677,
    57806,
    61935,
    4657,
    528,
    12915,
    8786,
    21173,
    17044,
    29431,
    25302,
    37689,
    33560,
    45947,
    41818,
    54205,
    50076,
    62463,
    58334,
    9314,
    13379,
    1056,
    5121,
    25830,
    29895,
    17572,
    21637,
    42346,
    46411,
    34088,
    38153,
    58862,
    62927,
    50604,
    54669,
    13907,
    9842,
    5649,
    1584,
    30423,
    26358,
    22165,
    18100,
    46939,
    42874,
    38681,
    34616,
    63455,
    59390,
    55197,
    51132,
    18628,
    22757,
    26758,
    30887,
    2112,
    6241,
    10242,
    14371,
    51660,
    55789,
    59790,
    63919,
    35144,
    39273,
    43274,
    47403,
    23285,
    19156,
    31415,
    27286,
    6769,
    2640,
    14899,
    10770,
    56317,
    52188,
    64447,
    60318,
    39801,
    35672,
    47931,
    43802,
    27814,
    31879,
    19684,
    23749,
    11298,
    15363,
    3168,
    7233,
    60846,
    64911,
    52716,
    56781,
    44330,
    48395,
    36200,
    40265,
    32407,
    28342,
    24277,
    20212,
    15891,
    11826,
    7761,
    3696,
    65439,
    61374,
    57309,
    53244,
    48923,
    44858,
    40793,
    36728,
    37256,
    33193,
    45514,
    41451,
    53516,
    49453,
    61774,
    57711,
    4224,
    161,
    12482,
    8419,
    20484,
    16421,
    28742,
    24679,
    33721,
    37784,
    41979,
    46042,
    49981,
    54044,
    58239,
    62302,
    689,
    4752,
    8947,
    13010,
    16949,
    21012,
    25207,
    29270,
    46570,
    42443,
    38312,
    34185,
    62830,
    58703,
    54572,
    50445,
    13538,
    9411,
    5280,
    1153,
    29798,
    25671,
    21540,
    17413,
    42971,
    47098,
    34713,
    38840,
    59231,
    63358,
    50973,
    55100,
    9939,
    14066,
    1681,
    5808,
    26199,
    30326,
    17941,
    22068,
    55628,
    51565,
    63758,
    59695,
    39368,
    35305,
    47498,
    43435,
    22596,
    18533,
    30726,
    26663,
    6336,
    2273,
    14466,
    10403,
    52093,
    56156,
    60223,
    64286,
    35833,
    39896,
    43963,
    48026,
    19061,
    23124,
    27191,
    31254,
    2801,
    6864,
    10931,
    14994,
    64814,
    60687,
    56684,
    52557,
    48554,
    44427,
    40424,
    36297,
    31782,
    27655,
    23652,
    19525,
    15522,
    11395,
    7392,
    3265,
    61215,
    65342,
    53085,
    57212,
    44955,
    49082,
    36825,
    40952,
    28183,
    32310,
    20053,
    24180,
    11923,
    16050,
    3793,
    7920
  ];
  var toUTF8Array = function toUTF8Array2(str) {
    var char;
    var i = 0;
    var p = 0;
    var utf8 = [];
    var len = str.length;
    for (;i < len; i++) {
      char = str.charCodeAt(i);
      if (char < 128) {
        utf8[p++] = char;
      } else if (char < 2048) {
        utf8[p++] = char >> 6 | 192;
        utf8[p++] = char & 63 | 128;
      } else if ((char & 64512) === 55296 && i + 1 < str.length && (str.charCodeAt(i + 1) & 64512) === 56320) {
        char = 65536 + ((char & 1023) << 10) + (str.charCodeAt(++i) & 1023);
        utf8[p++] = char >> 18 | 240;
        utf8[p++] = char >> 12 & 63 | 128;
        utf8[p++] = char >> 6 & 63 | 128;
        utf8[p++] = char & 63 | 128;
      } else {
        utf8[p++] = char >> 12 | 224;
        utf8[p++] = char >> 6 & 63 | 128;
        utf8[p++] = char & 63 | 128;
      }
    }
    return utf8;
  };
  var generate = module.exports = function generate2(str) {
    var char;
    var i = 0;
    var start = -1;
    var result = 0;
    var resultHash = 0;
    var utf8 = typeof str === "string" ? toUTF8Array(str) : str;
    var len = utf8.length;
    while (i < len) {
      char = utf8[i++];
      if (start === -1) {
        if (char === 123) {
          start = i;
        }
      } else if (char !== 125) {
        resultHash = lookup[(char ^ resultHash >> 8) & 255] ^ resultHash << 8;
      } else if (i - 1 !== start) {
        return resultHash & 16383;
      }
      result = lookup[(char ^ result >> 8) & 255] ^ result << 8;
    }
    return result & 16383;
  };
  module.exports.generateMulti = function generateMulti(keys) {
    var i = 1;
    var len = keys.length;
    var base = generate(keys[0]);
    while (i < len) {
      if (generate(keys[i++]) !== base)
        return -1;
    }
    return base;
  };
});

// node_modules/lodash.defaults/index.js
var require_lodash = __commonJS((exports, module) => {
  var MAX_SAFE_INTEGER = 9007199254740991;
  var argsTag = "[object Arguments]";
  var funcTag = "[object Function]";
  var genTag = "[object GeneratorFunction]";
  var reIsUint = /^(?:0|[1-9]\d*)$/;
  function apply(func, thisArg, args) {
    switch (args.length) {
      case 0:
        return func.call(thisArg);
      case 1:
        return func.call(thisArg, args[0]);
      case 2:
        return func.call(thisArg, args[0], args[1]);
      case 3:
        return func.call(thisArg, args[0], args[1], args[2]);
    }
    return func.apply(thisArg, args);
  }
  function baseTimes(n, iteratee) {
    var index = -1, result = Array(n);
    while (++index < n) {
      result[index] = iteratee(index);
    }
    return result;
  }
  var objectProto = Object.prototype;
  var hasOwnProperty = objectProto.hasOwnProperty;
  var objectToString = objectProto.toString;
  var propertyIsEnumerable = objectProto.propertyIsEnumerable;
  var nativeMax = Math.max;
  function arrayLikeKeys(value, inherited) {
    var result = isArray(value) || isArguments(value) ? baseTimes(value.length, String) : [];
    var length = result.length, skipIndexes = !!length;
    for (var key in value) {
      if ((inherited || hasOwnProperty.call(value, key)) && !(skipIndexes && (key == "length" || isIndex(key, length)))) {
        result.push(key);
      }
    }
    return result;
  }
  function assignInDefaults(objValue, srcValue, key, object) {
    if (objValue === undefined || eq(objValue, objectProto[key]) && !hasOwnProperty.call(object, key)) {
      return srcValue;
    }
    return objValue;
  }
  function assignValue(object, key, value) {
    var objValue = object[key];
    if (!(hasOwnProperty.call(object, key) && eq(objValue, value)) || value === undefined && !(key in object)) {
      object[key] = value;
    }
  }
  function baseKeysIn(object) {
    if (!isObject(object)) {
      return nativeKeysIn(object);
    }
    var isProto = isPrototype(object), result = [];
    for (var key in object) {
      if (!(key == "constructor" && (isProto || !hasOwnProperty.call(object, key)))) {
        result.push(key);
      }
    }
    return result;
  }
  function baseRest(func, start) {
    start = nativeMax(start === undefined ? func.length - 1 : start, 0);
    return function() {
      var args = arguments, index = -1, length = nativeMax(args.length - start, 0), array = Array(length);
      while (++index < length) {
        array[index] = args[start + index];
      }
      index = -1;
      var otherArgs = Array(start + 1);
      while (++index < start) {
        otherArgs[index] = args[index];
      }
      otherArgs[start] = array;
      return apply(func, this, otherArgs);
    };
  }
  function copyObject(source, props, object, customizer) {
    object || (object = {});
    var index = -1, length = props.length;
    while (++index < length) {
      var key = props[index];
      var newValue = customizer ? customizer(object[key], source[key], key, object, source) : undefined;
      assignValue(object, key, newValue === undefined ? source[key] : newValue);
    }
    return object;
  }
  function createAssigner(assigner) {
    return baseRest(function(object, sources) {
      var index = -1, length = sources.length, customizer = length > 1 ? sources[length - 1] : undefined, guard = length > 2 ? sources[2] : undefined;
      customizer = assigner.length > 3 && typeof customizer == "function" ? (length--, customizer) : undefined;
      if (guard && isIterateeCall(sources[0], sources[1], guard)) {
        customizer = length < 3 ? undefined : customizer;
        length = 1;
      }
      object = Object(object);
      while (++index < length) {
        var source = sources[index];
        if (source) {
          assigner(object, source, index, customizer);
        }
      }
      return object;
    });
  }
  function isIndex(value, length) {
    length = length == null ? MAX_SAFE_INTEGER : length;
    return !!length && (typeof value == "number" || reIsUint.test(value)) && (value > -1 && value % 1 == 0 && value < length);
  }
  function isIterateeCall(value, index, object) {
    if (!isObject(object)) {
      return false;
    }
    var type = typeof index;
    if (type == "number" ? isArrayLike(object) && isIndex(index, object.length) : type == "string" && (index in object)) {
      return eq(object[index], value);
    }
    return false;
  }
  function isPrototype(value) {
    var Ctor = value && value.constructor, proto = typeof Ctor == "function" && Ctor.prototype || objectProto;
    return value === proto;
  }
  function nativeKeysIn(object) {
    var result = [];
    if (object != null) {
      for (var key in Object(object)) {
        result.push(key);
      }
    }
    return result;
  }
  function eq(value, other) {
    return value === other || value !== value && other !== other;
  }
  function isArguments(value) {
    return isArrayLikeObject(value) && hasOwnProperty.call(value, "callee") && (!propertyIsEnumerable.call(value, "callee") || objectToString.call(value) == argsTag);
  }
  var isArray = Array.isArray;
  function isArrayLike(value) {
    return value != null && isLength(value.length) && !isFunction(value);
  }
  function isArrayLikeObject(value) {
    return isObjectLike(value) && isArrayLike(value);
  }
  function isFunction(value) {
    var tag = isObject(value) ? objectToString.call(value) : "";
    return tag == funcTag || tag == genTag;
  }
  function isLength(value) {
    return typeof value == "number" && value > -1 && value % 1 == 0 && value <= MAX_SAFE_INTEGER;
  }
  function isObject(value) {
    var type = typeof value;
    return !!value && (type == "object" || type == "function");
  }
  function isObjectLike(value) {
    return !!value && typeof value == "object";
  }
  var assignInWith = createAssigner(function(object, source, srcIndex, customizer) {
    copyObject(source, keysIn(source), object, customizer);
  });
  var defaults = baseRest(function(args) {
    args.push(undefined, assignInDefaults);
    return apply(assignInWith, undefined, args);
  });
  function keysIn(object) {
    return isArrayLike(object) ? arrayLikeKeys(object, true) : baseKeysIn(object);
  }
  module.exports = defaults;
});

// node_modules/lodash.isarguments/index.js
var require_lodash2 = __commonJS((exports, module) => {
  var MAX_SAFE_INTEGER = 9007199254740991;
  var argsTag = "[object Arguments]";
  var funcTag = "[object Function]";
  var genTag = "[object GeneratorFunction]";
  var objectProto = Object.prototype;
  var hasOwnProperty = objectProto.hasOwnProperty;
  var objectToString = objectProto.toString;
  var propertyIsEnumerable = objectProto.propertyIsEnumerable;
  function isArguments(value) {
    return isArrayLikeObject(value) && hasOwnProperty.call(value, "callee") && (!propertyIsEnumerable.call(value, "callee") || objectToString.call(value) == argsTag);
  }
  function isArrayLike(value) {
    return value != null && isLength(value.length) && !isFunction(value);
  }
  function isArrayLikeObject(value) {
    return isObjectLike(value) && isArrayLike(value);
  }
  function isFunction(value) {
    var tag = isObject(value) ? objectToString.call(value) : "";
    return tag == funcTag || tag == genTag;
  }
  function isLength(value) {
    return typeof value == "number" && value > -1 && value % 1 == 0 && value <= MAX_SAFE_INTEGER;
  }
  function isObject(value) {
    var type = typeof value;
    return !!value && (type == "object" || type == "function");
  }
  function isObjectLike(value) {
    return !!value && typeof value == "object";
  }
  module.exports = isArguments;
});

// node_modules/ioredis/built/utils/lodash.js
var require_lodash3 = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.isArguments = exports.defaults = exports.noop = undefined;
  var defaults = require_lodash();
  exports.defaults = defaults;
  var isArguments = require_lodash2();
  exports.isArguments = isArguments;
  function noop() {}
  exports.noop = noop;
});

// node_modules/ms/index.js
var require_ms = __commonJS((exports, module) => {
  var s = 1000;
  var m = s * 60;
  var h = m * 60;
  var d = h * 24;
  var w = d * 7;
  var y = d * 365.25;
  module.exports = function(val, options) {
    options = options || {};
    var type = typeof val;
    if (type === "string" && val.length > 0) {
      return parse(val);
    } else if (type === "number" && isFinite(val)) {
      return options.long ? fmtLong(val) : fmtShort(val);
    }
    throw new Error("val is not a non-empty string or a valid number. val=" + JSON.stringify(val));
  };
  function parse(str) {
    str = String(str);
    if (str.length > 100) {
      return;
    }
    var match = /^(-?(?:\d+)?\.?\d+) *(milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)?$/i.exec(str);
    if (!match) {
      return;
    }
    var n = parseFloat(match[1]);
    var type = (match[2] || "ms").toLowerCase();
    switch (type) {
      case "years":
      case "year":
      case "yrs":
      case "yr":
      case "y":
        return n * y;
      case "weeks":
      case "week":
      case "w":
        return n * w;
      case "days":
      case "day":
      case "d":
        return n * d;
      case "hours":
      case "hour":
      case "hrs":
      case "hr":
      case "h":
        return n * h;
      case "minutes":
      case "minute":
      case "mins":
      case "min":
      case "m":
        return n * m;
      case "seconds":
      case "second":
      case "secs":
      case "sec":
      case "s":
        return n * s;
      case "milliseconds":
      case "millisecond":
      case "msecs":
      case "msec":
      case "ms":
        return n;
      default:
        return;
    }
  }
  function fmtShort(ms) {
    var msAbs = Math.abs(ms);
    if (msAbs >= d) {
      return Math.round(ms / d) + "d";
    }
    if (msAbs >= h) {
      return Math.round(ms / h) + "h";
    }
    if (msAbs >= m) {
      return Math.round(ms / m) + "m";
    }
    if (msAbs >= s) {
      return Math.round(ms / s) + "s";
    }
    return ms + "ms";
  }
  function fmtLong(ms) {
    var msAbs = Math.abs(ms);
    if (msAbs >= d) {
      return plural(ms, msAbs, d, "day");
    }
    if (msAbs >= h) {
      return plural(ms, msAbs, h, "hour");
    }
    if (msAbs >= m) {
      return plural(ms, msAbs, m, "minute");
    }
    if (msAbs >= s) {
      return plural(ms, msAbs, s, "second");
    }
    return ms + " ms";
  }
  function plural(ms, msAbs, n, name) {
    var isPlural = msAbs >= n * 1.5;
    return Math.round(ms / n) + " " + name + (isPlural ? "s" : "");
  }
});

// node_modules/debug/src/common.js
var require_common = __commonJS((exports, module) => {
  function setup(env) {
    createDebug.debug = createDebug;
    createDebug.default = createDebug;
    createDebug.coerce = coerce;
    createDebug.disable = disable;
    createDebug.enable = enable;
    createDebug.enabled = enabled;
    createDebug.humanize = require_ms();
    createDebug.destroy = destroy;
    Object.keys(env).forEach((key) => {
      createDebug[key] = env[key];
    });
    createDebug.names = [];
    createDebug.skips = [];
    createDebug.formatters = {};
    function selectColor(namespace) {
      let hash = 0;
      for (let i = 0;i < namespace.length; i++) {
        hash = (hash << 5) - hash + namespace.charCodeAt(i);
        hash |= 0;
      }
      return createDebug.colors[Math.abs(hash) % createDebug.colors.length];
    }
    createDebug.selectColor = selectColor;
    function createDebug(namespace) {
      let prevTime;
      let enableOverride = null;
      let namespacesCache;
      let enabledCache;
      function debug(...args) {
        if (!debug.enabled) {
          return;
        }
        const self = debug;
        const curr = Number(new Date);
        const ms = curr - (prevTime || curr);
        self.diff = ms;
        self.prev = prevTime;
        self.curr = curr;
        prevTime = curr;
        args[0] = createDebug.coerce(args[0]);
        if (typeof args[0] !== "string") {
          args.unshift("%O");
        }
        let index = 0;
        args[0] = args[0].replace(/%([a-zA-Z%])/g, (match, format) => {
          if (match === "%%") {
            return "%";
          }
          index++;
          const formatter = createDebug.formatters[format];
          if (typeof formatter === "function") {
            const val = args[index];
            match = formatter.call(self, val);
            args.splice(index, 1);
            index--;
          }
          return match;
        });
        createDebug.formatArgs.call(self, args);
        const logFn = self.log || createDebug.log;
        logFn.apply(self, args);
      }
      debug.namespace = namespace;
      debug.useColors = createDebug.useColors();
      debug.color = createDebug.selectColor(namespace);
      debug.extend = extend;
      debug.destroy = createDebug.destroy;
      Object.defineProperty(debug, "enabled", {
        enumerable: true,
        configurable: false,
        get: () => {
          if (enableOverride !== null) {
            return enableOverride;
          }
          if (namespacesCache !== createDebug.namespaces) {
            namespacesCache = createDebug.namespaces;
            enabledCache = createDebug.enabled(namespace);
          }
          return enabledCache;
        },
        set: (v) => {
          enableOverride = v;
        }
      });
      if (typeof createDebug.init === "function") {
        createDebug.init(debug);
      }
      return debug;
    }
    function extend(namespace, delimiter) {
      const newDebug = createDebug(this.namespace + (typeof delimiter === "undefined" ? ":" : delimiter) + namespace);
      newDebug.log = this.log;
      return newDebug;
    }
    function enable(namespaces) {
      createDebug.save(namespaces);
      createDebug.namespaces = namespaces;
      createDebug.names = [];
      createDebug.skips = [];
      const split = (typeof namespaces === "string" ? namespaces : "").trim().replace(/\s+/g, ",").split(",").filter(Boolean);
      for (const ns of split) {
        if (ns[0] === "-") {
          createDebug.skips.push(ns.slice(1));
        } else {
          createDebug.names.push(ns);
        }
      }
    }
    function matchesTemplate(search, template) {
      let searchIndex = 0;
      let templateIndex = 0;
      let starIndex = -1;
      let matchIndex = 0;
      while (searchIndex < search.length) {
        if (templateIndex < template.length && (template[templateIndex] === search[searchIndex] || template[templateIndex] === "*")) {
          if (template[templateIndex] === "*") {
            starIndex = templateIndex;
            matchIndex = searchIndex;
            templateIndex++;
          } else {
            searchIndex++;
            templateIndex++;
          }
        } else if (starIndex !== -1) {
          templateIndex = starIndex + 1;
          matchIndex++;
          searchIndex = matchIndex;
        } else {
          return false;
        }
      }
      while (templateIndex < template.length && template[templateIndex] === "*") {
        templateIndex++;
      }
      return templateIndex === template.length;
    }
    function disable() {
      const namespaces = [
        ...createDebug.names,
        ...createDebug.skips.map((namespace) => "-" + namespace)
      ].join(",");
      createDebug.enable("");
      return namespaces;
    }
    function enabled(name) {
      for (const skip of createDebug.skips) {
        if (matchesTemplate(name, skip)) {
          return false;
        }
      }
      for (const ns of createDebug.names) {
        if (matchesTemplate(name, ns)) {
          return true;
        }
      }
      return false;
    }
    function coerce(val) {
      if (val instanceof Error) {
        return val.stack || val.message;
      }
      return val;
    }
    function destroy() {
      console.warn("Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`.");
    }
    createDebug.enable(createDebug.load());
    return createDebug;
  }
  module.exports = setup;
});

// node_modules/debug/src/browser.js
var require_browser = __commonJS((exports, module) => {
  exports.formatArgs = formatArgs;
  exports.save = save;
  exports.load = load;
  exports.useColors = useColors;
  exports.storage = localstorage();
  exports.destroy = (() => {
    let warned = false;
    return () => {
      if (!warned) {
        warned = true;
        console.warn("Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`.");
      }
    };
  })();
  exports.colors = [
    "#0000CC",
    "#0000FF",
    "#0033CC",
    "#0033FF",
    "#0066CC",
    "#0066FF",
    "#0099CC",
    "#0099FF",
    "#00CC00",
    "#00CC33",
    "#00CC66",
    "#00CC99",
    "#00CCCC",
    "#00CCFF",
    "#3300CC",
    "#3300FF",
    "#3333CC",
    "#3333FF",
    "#3366CC",
    "#3366FF",
    "#3399CC",
    "#3399FF",
    "#33CC00",
    "#33CC33",
    "#33CC66",
    "#33CC99",
    "#33CCCC",
    "#33CCFF",
    "#6600CC",
    "#6600FF",
    "#6633CC",
    "#6633FF",
    "#66CC00",
    "#66CC33",
    "#9900CC",
    "#9900FF",
    "#9933CC",
    "#9933FF",
    "#99CC00",
    "#99CC33",
    "#CC0000",
    "#CC0033",
    "#CC0066",
    "#CC0099",
    "#CC00CC",
    "#CC00FF",
    "#CC3300",
    "#CC3333",
    "#CC3366",
    "#CC3399",
    "#CC33CC",
    "#CC33FF",
    "#CC6600",
    "#CC6633",
    "#CC9900",
    "#CC9933",
    "#CCCC00",
    "#CCCC33",
    "#FF0000",
    "#FF0033",
    "#FF0066",
    "#FF0099",
    "#FF00CC",
    "#FF00FF",
    "#FF3300",
    "#FF3333",
    "#FF3366",
    "#FF3399",
    "#FF33CC",
    "#FF33FF",
    "#FF6600",
    "#FF6633",
    "#FF9900",
    "#FF9933",
    "#FFCC00",
    "#FFCC33"
  ];
  function useColors() {
    if (typeof window !== "undefined" && window.process && (window.process.type === "renderer" || window.process.__nwjs)) {
      return true;
    }
    if (typeof navigator !== "undefined" && navigator.userAgent && navigator.userAgent.toLowerCase().match(/(edge|trident)\/(\d+)/)) {
      return false;
    }
    let m;
    return typeof document !== "undefined" && document.documentElement && document.documentElement.style && document.documentElement.style.WebkitAppearance || typeof window !== "undefined" && window.console && (window.console.firebug || window.console.exception && window.console.table) || typeof navigator !== "undefined" && navigator.userAgent && (m = navigator.userAgent.toLowerCase().match(/firefox\/(\d+)/)) && parseInt(m[1], 10) >= 31 || typeof navigator !== "undefined" && navigator.userAgent && navigator.userAgent.toLowerCase().match(/applewebkit\/(\d+)/);
  }
  function formatArgs(args) {
    args[0] = (this.useColors ? "%c" : "") + this.namespace + (this.useColors ? " %c" : " ") + args[0] + (this.useColors ? "%c " : " ") + "+" + module.exports.humanize(this.diff);
    if (!this.useColors) {
      return;
    }
    const c = "color: " + this.color;
    args.splice(1, 0, c, "color: inherit");
    let index = 0;
    let lastC = 0;
    args[0].replace(/%[a-zA-Z%]/g, (match) => {
      if (match === "%%") {
        return;
      }
      index++;
      if (match === "%c") {
        lastC = index;
      }
    });
    args.splice(lastC, 0, c);
  }
  exports.log = console.debug || console.log || (() => {});
  function save(namespaces) {
    try {
      if (namespaces) {
        exports.storage.setItem("debug", namespaces);
      } else {
        exports.storage.removeItem("debug");
      }
    } catch (error) {}
  }
  function load() {
    let r;
    try {
      r = exports.storage.getItem("debug") || exports.storage.getItem("DEBUG");
    } catch (error) {}
    if (!r && typeof process !== "undefined" && "env" in process) {
      r = process.env.DEBUG;
    }
    return r;
  }
  function localstorage() {
    try {
      return localStorage;
    } catch (error) {}
  }
  module.exports = require_common()(exports);
  var { formatters } = module.exports;
  formatters.j = function(v) {
    try {
      return JSON.stringify(v);
    } catch (error) {
      return "[UnexpectedJSONParseError]: " + error.message;
    }
  };
});

// node_modules/debug/src/node.js
var require_node = __commonJS((exports, module) => {
  var tty = __require("tty");
  var util = __require("util");
  exports.init = init;
  exports.log = log;
  exports.formatArgs = formatArgs;
  exports.save = save;
  exports.load = load;
  exports.useColors = useColors;
  exports.destroy = util.deprecate(() => {}, "Instance method `debug.destroy()` is deprecated and no longer does anything. It will be removed in the next major version of `debug`.");
  exports.colors = [6, 2, 3, 4, 5, 1];
  try {
    const supportsColor = (()=>{throw new Error("Cannot require module "+"supports-color");})();
    if (supportsColor && (supportsColor.stderr || supportsColor).level >= 2) {
      exports.colors = [
        20,
        21,
        26,
        27,
        32,
        33,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        56,
        57,
        62,
        63,
        68,
        69,
        74,
        75,
        76,
        77,
        78,
        79,
        80,
        81,
        92,
        93,
        98,
        99,
        112,
        113,
        128,
        129,
        134,
        135,
        148,
        149,
        160,
        161,
        162,
        163,
        164,
        165,
        166,
        167,
        168,
        169,
        170,
        171,
        172,
        173,
        178,
        179,
        184,
        185,
        196,
        197,
        198,
        199,
        200,
        201,
        202,
        203,
        204,
        205,
        206,
        207,
        208,
        209,
        214,
        215,
        220,
        221
      ];
    }
  } catch (error) {}
  exports.inspectOpts = Object.keys(process.env).filter((key) => {
    return /^debug_/i.test(key);
  }).reduce((obj, key) => {
    const prop = key.substring(6).toLowerCase().replace(/_([a-z])/g, (_, k) => {
      return k.toUpperCase();
    });
    let val = process.env[key];
    if (/^(yes|on|true|enabled)$/i.test(val)) {
      val = true;
    } else if (/^(no|off|false|disabled)$/i.test(val)) {
      val = false;
    } else if (val === "null") {
      val = null;
    } else {
      val = Number(val);
    }
    obj[prop] = val;
    return obj;
  }, {});
  function useColors() {
    return "colors" in exports.inspectOpts ? Boolean(exports.inspectOpts.colors) : tty.isatty(process.stderr.fd);
  }
  function formatArgs(args) {
    const { namespace: name, useColors: useColors2 } = this;
    if (useColors2) {
      const c = this.color;
      const colorCode = "\x1B[3" + (c < 8 ? c : "8;5;" + c);
      const prefix = `  ${colorCode};1m${name} \x1B[0m`;
      args[0] = prefix + args[0].split(`
`).join(`
` + prefix);
      args.push(colorCode + "m+" + module.exports.humanize(this.diff) + "\x1B[0m");
    } else {
      args[0] = getDate() + name + " " + args[0];
    }
  }
  function getDate() {
    if (exports.inspectOpts.hideDate) {
      return "";
    }
    return new Date().toISOString() + " ";
  }
  function log(...args) {
    return process.stderr.write(util.formatWithOptions(exports.inspectOpts, ...args) + `
`);
  }
  function save(namespaces) {
    if (namespaces) {
      process.env.DEBUG = namespaces;
    } else {
      delete process.env.DEBUG;
    }
  }
  function load() {
    return process.env.DEBUG;
  }
  function init(debug) {
    debug.inspectOpts = {};
    const keys = Object.keys(exports.inspectOpts);
    for (let i = 0;i < keys.length; i++) {
      debug.inspectOpts[keys[i]] = exports.inspectOpts[keys[i]];
    }
  }
  module.exports = require_common()(exports);
  var { formatters } = module.exports;
  formatters.o = function(v) {
    this.inspectOpts.colors = this.useColors;
    return util.inspect(v, this.inspectOpts).split(`
`).map((str) => str.trim()).join(" ");
  };
  formatters.O = function(v) {
    this.inspectOpts.colors = this.useColors;
    return util.inspect(v, this.inspectOpts);
  };
});

// node_modules/debug/src/index.js
var require_src = __commonJS((exports, module) => {
  if (typeof process === "undefined" || process.type === "renderer" || false || process.__nwjs) {
    module.exports = require_browser();
  } else {
    module.exports = require_node();
  }
});

// node_modules/ioredis/built/utils/debug.js
var require_debug = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.genRedactedString = exports.getStringValue = exports.MAX_ARGUMENT_LENGTH = undefined;
  var debug_1 = require_src();
  var MAX_ARGUMENT_LENGTH = 200;
  exports.MAX_ARGUMENT_LENGTH = MAX_ARGUMENT_LENGTH;
  var NAMESPACE_PREFIX = "ioredis";
  function getStringValue(v) {
    if (v === null) {
      return;
    }
    switch (typeof v) {
      case "boolean":
        return;
      case "number":
        return;
      case "object":
        if (Buffer.isBuffer(v)) {
          return v.toString("hex");
        }
        if (Array.isArray(v)) {
          return v.join(",");
        }
        try {
          return JSON.stringify(v);
        } catch (e) {
          return;
        }
      case "string":
        return v;
    }
  }
  exports.getStringValue = getStringValue;
  function genRedactedString(str, maxLen) {
    const { length } = str;
    return length <= maxLen ? str : str.slice(0, maxLen) + ' ... <REDACTED full-length="' + length + '">';
  }
  exports.genRedactedString = genRedactedString;
  function genDebugFunction(namespace) {
    const fn = (0, debug_1.default)(`${NAMESPACE_PREFIX}:${namespace}`);
    function wrappedDebug(...args) {
      if (!fn.enabled) {
        return;
      }
      for (let i = 1;i < args.length; i++) {
        const str = getStringValue(args[i]);
        if (typeof str === "string" && str.length > MAX_ARGUMENT_LENGTH) {
          args[i] = genRedactedString(str, MAX_ARGUMENT_LENGTH);
        }
      }
      return fn.apply(null, args);
    }
    Object.defineProperties(wrappedDebug, {
      namespace: {
        get() {
          return fn.namespace;
        }
      },
      enabled: {
        get() {
          return fn.enabled;
        }
      },
      destroy: {
        get() {
          return fn.destroy;
        }
      },
      log: {
        get() {
          return fn.log;
        },
        set(l) {
          fn.log = l;
        }
      }
    });
    return wrappedDebug;
  }
  exports.default = genDebugFunction;
});

// node_modules/ioredis/built/constants/TLSProfiles.js
var require_TLSProfiles = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var RedisCloudCA = `-----BEGIN CERTIFICATE-----
MIIDTzCCAjegAwIBAgIJAKSVpiDswLcwMA0GCSqGSIb3DQEBBQUAMD4xFjAUBgNV
BAoMDUdhcmFudGlhIERhdGExJDAiBgNVBAMMG1NTTCBDZXJ0aWZpY2F0aW9uIEF1
dGhvcml0eTAeFw0xMzEwMDExMjE0NTVaFw0yMzA5MjkxMjE0NTVaMD4xFjAUBgNV
BAoMDUdhcmFudGlhIERhdGExJDAiBgNVBAMMG1NTTCBDZXJ0aWZpY2F0aW9uIEF1
dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALZqkh/DczWP
JnxnHLQ7QL0T4B4CDKWBKCcisriGbA6ZePWVNo4hfKQC6JrzfR+081NeD6VcWUiz
rmd+jtPhIY4c+WVQYm5PKaN6DT1imYdxQw7aqO5j2KUCEh/cznpLxeSHoTxlR34E
QwF28Wl3eg2vc5ct8LjU3eozWVk3gb7alx9mSA2SgmuX5lEQawl++rSjsBStemY2
BDwOpAMXIrdEyP/cVn8mkvi/BDs5M5G+09j0gfhyCzRWMQ7Hn71u1eolRxwVxgi3
TMn+/vTaFSqxKjgck6zuAYjBRPaHe7qLxHNr1So/Mc9nPy+3wHebFwbIcnUojwbp
4nctkWbjb2cCAwEAAaNQME4wHQYDVR0OBBYEFP1whtcrydmW3ZJeuSoKZIKjze3w
MB8GA1UdIwQYMBaAFP1whtcrydmW3ZJeuSoKZIKjze3wMAwGA1UdEwQFMAMBAf8w
DQYJKoZIhvcNAQEFBQADggEBAG2erXhwRAa7+ZOBs0B6X57Hwyd1R4kfmXcs0rta
lbPpvgULSiB+TCbf3EbhJnHGyvdCY1tvlffLjdA7HJ0PCOn+YYLBA0pTU/dyvrN6
Su8NuS5yubnt9mb13nDGYo1rnt0YRfxN+8DM3fXIVr038A30UlPX2Ou1ExFJT0MZ
uFKY6ZvLdI6/1cbgmguMlAhM+DhKyV6Sr5699LM3zqeI816pZmlREETYkGr91q7k
BpXJu/dtHaGxg1ZGu6w/PCsYGUcECWENYD4VQPd8N32JjOfu6vEgoEAwfPP+3oGp
Z4m3ewACcWOAenqflb+cQYC4PsF7qbXDmRaWrbKntOlZ3n0=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIGMTCCBBmgAwIBAgICEAAwDQYJKoZIhvcNAQELBQAwajELMAkGA1UEBhMCVVMx
CzAJBgNVBAgMAkNBMQswCQYDVQQHDAJDQTESMBAGA1UECgwJUmVkaXNMYWJzMS0w
KwYDVQQDDCRSZWRpc0xhYnMgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcN
MTgwMjI1MTUzNzM3WhcNMjgwMjIzMTUzNzM3WjBfMQswCQYDVQQGEwJVUzELMAkG
A1UECAwCQ0ExEjAQBgNVBAoMCVJlZGlzTGFiczEvMC0GA1UEAwwmUkNQIEludGVy
bWVkaWF0ZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQDf9dqbxc8Bq7Ctq9rWcxrGNKKHivqLAFpPq02yLPx6fsOv
Tq7GsDChAYBBc4v7Y2Ap9RD5Vs3dIhEANcnolf27QwrG9RMnnvzk8pCvp1o6zSU4
VuOE1W66/O1/7e2rVxyrnTcP7UgK43zNIXu7+tiAqWsO92uSnuMoGPGpeaUm1jym
hjWKtkAwDFSqvHY+XL5qDVBEjeUe+WHkYUg40cAXjusAqgm2hZt29c2wnVrxW25W
P0meNlzHGFdA2AC5z54iRiqj57dTfBTkHoBczQxcyw6hhzxZQ4e5I5zOKjXXEhZN
r0tA3YC14CTabKRus/JmZieyZzRgEy2oti64tmLYTqSlAD78pRL40VNoaSYetXLw
hhNsXCHgWaY6d5bLOc/aIQMAV5oLvZQKvuXAF1IDmhPA+bZbpWipp0zagf1P1H3s
UzsMdn2KM0ejzgotbtNlj5TcrVwpmvE3ktvUAuA+hi3FkVx1US+2Gsp5x4YOzJ7u
P1WPk6ShF0JgnJH2ILdj6kttTWwFzH17keSFICWDfH/+kM+k7Y1v3EXMQXE7y0T9
MjvJskz6d/nv+sQhY04xt64xFMGTnZjlJMzfQNi7zWFLTZnDD0lPowq7l3YiPoTT
t5Xky83lu0KZsZBo0WlWaDG00gLVdtRgVbcuSWxpi5BdLb1kRab66JptWjxwXQID
AQABo4HrMIHoMDoGA1UdHwQzMDEwL6AtoCuGKWh0dHBzOi8vcmwtY2Etc2VydmVy
LnJlZGlzbGFicy5jb20vdjEvY3JsMEYGCCsGAQUFBwEBBDowODA2BggrBgEFBQcw
AYYqaHR0cHM6Ly9ybC1jYS1zZXJ2ZXIucmVkaXNsYWJzLmNvbS92MS9vY3NwMB0G
A1UdDgQWBBQHar5OKvQUpP2qWt6mckzToeCOHDAfBgNVHSMEGDAWgBQi42wH6hM4
L2sujEvLM0/u8lRXTzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIB
hjANBgkqhkiG9w0BAQsFAAOCAgEAirEn/iTsAKyhd+pu2W3Z5NjCko4NPU0EYUbr
AP7+POK2rzjIrJO3nFYQ/LLuC7KCXG+2qwan2SAOGmqWst13Y+WHp44Kae0kaChW
vcYLXXSoGQGC8QuFSNUdaeg3RbMDYFT04dOkqufeWVccoHVxyTSg9eD8LZuHn5jw
7QDLiEECBmIJHk5Eeo2TAZrx4Yx6ufSUX5HeVjlAzqwtAqdt99uCJ/EL8bgpWbe+
XoSpvUv0SEC1I1dCAhCKAvRlIOA6VBcmzg5Am12KzkqTul12/VEFIgzqu0Zy2Jbc
AUPrYVu/+tOGXQaijy7YgwH8P8n3s7ZeUa1VABJHcxrxYduDDJBLZi+MjheUDaZ1
jQRHYevI2tlqeSBqdPKG4zBY5lS0GiAlmuze5oENt0P3XboHoZPHiqcK3VECgTVh
/BkJcuudETSJcZDmQ8YfoKfBzRQNg2sv/hwvUv73Ss51Sco8GEt2lD8uEdib1Q6z
zDT5lXJowSzOD5ZA9OGDjnSRL+2riNtKWKEqvtEG3VBJoBzu9GoxbAc7wIZLxmli
iF5a/Zf5X+UXD3s4TMmy6C4QZJpAA2egsSQCnraWO2ULhh7iXMysSkF/nzVfZn43
iqpaB8++9a37hWq14ZmOv0TJIDz//b2+KC4VFXWQ5W5QC6whsjT+OlG4p5ZYG0jo
616pxqo=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIFujCCA6KgAwIBAgIJAJ1aTT1lu2ScMA0GCSqGSIb3DQEBCwUAMGoxCzAJBgNV
BAYTAlVTMQswCQYDVQQIDAJDQTELMAkGA1UEBwwCQ0ExEjAQBgNVBAoMCVJlZGlz
TGFiczEtMCsGA1UEAwwkUmVkaXNMYWJzIFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MB4XDTE4MDIyNTE1MjA0MloXDTM4MDIyMDE1MjA0MlowajELMAkGA1UEBhMC
VVMxCzAJBgNVBAgMAkNBMQswCQYDVQQHDAJDQTESMBAGA1UECgwJUmVkaXNMYWJz
MS0wKwYDVQQDDCRSZWRpc0xhYnMgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkw
ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDLEjXy7YrbN5Waau5cd6g1
G5C2tMmeTpZ0duFAPxNU4oE3RHS5gGiok346fUXuUxbZ6QkuzeN2/2Z+RmRcJhQY
Dm0ZgdG4x59An1TJfnzKKoWj8ISmoHS/TGNBdFzXV7FYNLBuqZouqePI6ReC6Qhl
pp45huV32Q3a6IDrrvx7Wo5ZczEQeFNbCeCOQYNDdTmCyEkHqc2AGo8eoIlSTutT
ULOC7R5gzJVTS0e1hesQ7jmqHjbO+VQS1NAL4/5K6cuTEqUl+XhVhPdLWBXJQ5ag
54qhX4v+ojLzeU1R/Vc6NjMvVtptWY6JihpgplprN0Yh2556ewcXMeturcKgXfGJ
xeYzsjzXerEjrVocX5V8BNrg64NlifzTMKNOOv4fVZszq1SIHR8F9ROrqiOdh8iC
JpUbLpXH9hWCSEO6VRMB2xJoKu3cgl63kF30s77x7wLFMEHiwsQRKxooE1UhgS9K
2sO4TlQ1eWUvFvHSTVDQDlGQ6zu4qjbOpb3Q8bQwoK+ai2alkXVR4Ltxe9QlgYK3
StsnPhruzZGA0wbXdpw0bnM+YdlEm5ffSTpNIfgHeaa7Dtb801FtA71ZlH7A6TaI
SIQuUST9EKmv7xrJyx0W1pGoPOLw5T029aTjnICSLdtV9bLwysrLhIYG5bnPq78B
cS+jZHFGzD7PUVGQD01nOQIDAQABo2MwYTAdBgNVHQ4EFgQUIuNsB+oTOC9rLoxL
yzNP7vJUV08wHwYDVR0jBBgwFoAUIuNsB+oTOC9rLoxLyzNP7vJUV08wDwYDVR0T
AQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAYYwDQYJKoZIhvcNAQELBQADggIBAHfg
z5pMNUAKdMzK1aS1EDdK9yKz4qicILz5czSLj1mC7HKDRy8cVADUxEICis++CsCu
rYOvyCVergHQLREcxPq4rc5Nq1uj6J6649NEeh4WazOOjL4ZfQ1jVznMbGy+fJm3
3Hoelv6jWRG9iqeJZja7/1s6YC6bWymI/OY1e4wUKeNHAo+Vger7MlHV+RuabaX+
hSJ8bJAM59NCM7AgMTQpJCncrcdLeceYniGy5Q/qt2b5mJkQVkIdy4TPGGB+AXDJ
D0q3I/JDRkDUFNFdeW0js7fHdsvCR7O3tJy5zIgEV/o/BCkmJVtuwPYOrw/yOlKj
TY/U7ATAx9VFF6/vYEOMYSmrZlFX+98L6nJtwDqfLB5VTltqZ4H/KBxGE3IRSt9l
FXy40U+LnXzhhW+7VBAvyYX8GEXhHkKU8Gqk1xitrqfBXY74xKgyUSTolFSfFVgj
mcM/X4K45bka+qpkj7Kfv/8D4j6aZekwhN2ly6hhC1SmQ8qjMjpG/mrWOSSHZFmf
ybu9iD2AYHeIOkshIl6xYIa++Q/00/vs46IzAbQyriOi0XxlSMMVtPx0Q3isp+ji
n8Mq9eOuxYOEQ4of8twUkUDd528iwGtEdwf0Q01UyT84S62N8AySl1ZBKXJz6W4F
UhWfa/HQYOAPDdEjNgnVwLI23b8t0TozyCWw7q8h
-----END CERTIFICATE-----

-----BEGIN CERTIFICATE-----
MIIEjzCCA3egAwIBAgIQe55B/ALCKJDZtdNT8kD6hTANBgkqhkiG9w0BAQsFADBM
MSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSMzETMBEGA1UEChMKR2xv
YmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjAeFw0yMjAxMjYxMjAwMDBaFw0y
NTAxMjYwMDAwMDBaMFgxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWdu
IG52LXNhMS4wLAYDVQQDEyVHbG9iYWxTaWduIEF0bGFzIFIzIE9WIFRMUyBDQSAy
MDIyIFEyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmGmg1LW9b7Lf
8zDD83yBDTEkt+FOxKJZqF4veWc5KZsQj9HfnUS2e5nj/E+JImlGPsQuoiosLuXD
BVBNAMcUFa11buFMGMeEMwiTmCXoXRrXQmH0qjpOfKgYc5gHG3BsRGaRrf7VR4eg
ofNMG9wUBw4/g/TT7+bQJdA4NfE7Y4d5gEryZiBGB/swaX6Jp/8MF4TgUmOWmalK
dZCKyb4sPGQFRTtElk67F7vU+wdGcrcOx1tDcIB0ncjLPMnaFicagl+daWGsKqTh
counQb6QJtYHa91KvCfKWocMxQ7OIbB5UARLPmC4CJ1/f8YFm35ebfzAeULYdGXu
jE9CLor0OwIDAQABo4IBXzCCAVswDgYDVR0PAQH/BAQDAgGGMB0GA1UdJQQWMBQG
CCsGAQUFBwMBBggrBgEFBQcDAjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQW
BBSH5Zq7a7B/t95GfJWkDBpA8HHqdjAfBgNVHSMEGDAWgBSP8Et/qC5FJK5NUPpj
move4t0bvDB7BggrBgEFBQcBAQRvMG0wLgYIKwYBBQUHMAGGImh0dHA6Ly9vY3Nw
Mi5nbG9iYWxzaWduLmNvbS9yb290cjMwOwYIKwYBBQUHMAKGL2h0dHA6Ly9zZWN1
cmUuZ2xvYmFsc2lnbi5jb20vY2FjZXJ0L3Jvb3QtcjMuY3J0MDYGA1UdHwQvMC0w
K6ApoCeGJWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vcm9vdC1yMy5jcmwwIQYD
VR0gBBowGDAIBgZngQwBAgIwDAYKKwYBBAGgMgoBAjANBgkqhkiG9w0BAQsFAAOC
AQEAKRic9/f+nmhQU/wz04APZLjgG5OgsuUOyUEZjKVhNGDwxGTvKhyXGGAMW2B/
3bRi+aElpXwoxu3pL6fkElbX3B0BeS5LoDtxkyiVEBMZ8m+sXbocwlPyxrPbX6mY
0rVIvnuUeBH8X0L5IwfpNVvKnBIilTbcebfHyXkPezGwz7E1yhUULjJFm2bt0SdX
y+4X/WeiiYIv+fTVgZZgl+/2MKIsu/qdBJc3f3TvJ8nz+Eax1zgZmww+RSQWeOj3
15Iw6Z5FX+NwzY/Ab+9PosR5UosSeq+9HhtaxZttXG1nVh+avYPGYddWmiMT90J5
ZgKnO/Fx2hBgTxhOTMYaD312kg==
-----END CERTIFICATE-----

-----BEGIN CERTIFICATE-----
MIIDXzCCAkegAwIBAgILBAAAAAABIVhTCKIwDQYJKoZIhvcNAQELBQAwTDEgMB4G
A1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkdsb2JhbFNp
Z24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMDkwMzE4MTAwMDAwWhcNMjkwMzE4
MTAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSMzETMBEG
A1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAMwldpB5BngiFvXAg7aEyiie/QV2EcWtiHL8
RgJDx7KKnQRfJMsuS+FggkbhUqsMgUdwbN1k0ev1LKMPgj0MK66X17YUhhB5uzsT
gHeMCOFJ0mpiLx9e+pZo34knlTifBtc+ycsmWQ1z3rDI6SYOgxXG71uL0gRgykmm
KPZpO/bLyCiR5Z2KYVc3rHQU3HTgOu5yLy6c+9C7v/U9AOEGM+iCK65TpjoWc4zd
QQ4gOsC0p6Hpsk+QLjJg6VfLuQSSaGjlOCZgdbKfd/+RFO+uIEn8rUAVSNECMWEZ
XriX7613t2Saer9fwRPvm2L7DWzgVGkWqQPabumDk3F2xmmFghcCAwEAAaNCMEAw
DgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFI/wS3+o
LkUkrk1Q+mOai97i3Ru8MA0GCSqGSIb3DQEBCwUAA4IBAQBLQNvAUKr+yAzv95ZU
RUm7lgAJQayzE4aGKAczymvmdLm6AC2upArT9fHxD4q/c2dKg8dEe3jgr25sbwMp
jjM5RcOO5LlXbKr8EpbsU8Yt5CRsuZRj+9xTaGdWPoO4zzUhw8lo/s7awlOqzJCK
6fBdRoyV3XpYKBovHd7NADdBj+1EbddTKJd+82cEHhXXipa0095MJ6RMG3NzdvQX
mcIfeg7jLQitChws/zyrVQ4PkX4268NXSb7hLi18YIvDQVETI53O9zJrlAGomecs
Mx86OyXShkDOOyyGeMlhLxS67ttVb9+E7gUJTb0o2HLO02JQZR7rkpeDMdmztcpH
WD9f
-----END CERTIFICATE-----`;
  var TLSProfiles = {
    RedisCloudFixed: { ca: RedisCloudCA },
    RedisCloudFlexible: { ca: RedisCloudCA }
  };
  exports.default = TLSProfiles;
});

// node_modules/ioredis/built/utils/index.js
var require_utils2 = __commonJS((exports) => {
  var __dirname = "C:\\Users\\JavierEguren\\Desktop\\EntityWars\\entity-wars\\backend\\node_modules\\ioredis\\built\\utils";
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.noop = exports.defaults = exports.Debug = exports.getPackageMeta = exports.zipMap = exports.CONNECTION_CLOSED_ERROR_MSG = exports.shuffle = exports.sample = exports.resolveTLSProfile = exports.parseURL = exports.optimizeErrorStack = exports.toArg = exports.convertMapToArray = exports.convertObjectToArray = exports.timeout = exports.packObject = exports.isInt = exports.wrapMultiResult = exports.convertBufferToString = undefined;
  var fs_1 = __require("fs");
  var path_1 = __require("path");
  var url_1 = __require("url");
  var lodash_1 = require_lodash3();
  Object.defineProperty(exports, "defaults", { enumerable: true, get: function() {
    return lodash_1.defaults;
  } });
  Object.defineProperty(exports, "noop", { enumerable: true, get: function() {
    return lodash_1.noop;
  } });
  var debug_1 = require_debug();
  exports.Debug = debug_1.default;
  var TLSProfiles_1 = require_TLSProfiles();
  function convertBufferToString(value, encoding) {
    if (value instanceof Buffer) {
      return value.toString(encoding);
    }
    if (Array.isArray(value)) {
      const length = value.length;
      const res = Array(length);
      for (let i = 0;i < length; ++i) {
        res[i] = value[i] instanceof Buffer && encoding === "utf8" ? value[i].toString() : convertBufferToString(value[i], encoding);
      }
      return res;
    }
    return value;
  }
  exports.convertBufferToString = convertBufferToString;
  function wrapMultiResult(arr) {
    if (!arr) {
      return null;
    }
    const result = [];
    const length = arr.length;
    for (let i = 0;i < length; ++i) {
      const item = arr[i];
      if (item instanceof Error) {
        result.push([item]);
      } else {
        result.push([null, item]);
      }
    }
    return result;
  }
  exports.wrapMultiResult = wrapMultiResult;
  function isInt(value) {
    const x = parseFloat(value);
    return !isNaN(value) && (x | 0) === x;
  }
  exports.isInt = isInt;
  function packObject(array) {
    const result = {};
    const length = array.length;
    for (let i = 1;i < length; i += 2) {
      result[array[i - 1]] = array[i];
    }
    return result;
  }
  exports.packObject = packObject;
  function timeout(callback, timeout2) {
    let timer = null;
    const run = function() {
      if (timer) {
        clearTimeout(timer);
        timer = null;
        callback.apply(this, arguments);
      }
    };
    timer = setTimeout(run, timeout2, new Error("timeout"));
    return run;
  }
  exports.timeout = timeout;
  function convertObjectToArray(obj) {
    const result = [];
    const keys = Object.keys(obj);
    for (let i = 0, l = keys.length;i < l; i++) {
      result.push(keys[i], obj[keys[i]]);
    }
    return result;
  }
  exports.convertObjectToArray = convertObjectToArray;
  function convertMapToArray(map) {
    const result = [];
    let pos = 0;
    map.forEach(function(value, key) {
      result[pos] = key;
      result[pos + 1] = value;
      pos += 2;
    });
    return result;
  }
  exports.convertMapToArray = convertMapToArray;
  function toArg(arg) {
    if (arg === null || typeof arg === "undefined") {
      return "";
    }
    return String(arg);
  }
  exports.toArg = toArg;
  function optimizeErrorStack(error, friendlyStack, filterPath) {
    const stacks = friendlyStack.split(`
`);
    let lines = "";
    let i;
    for (i = 1;i < stacks.length; ++i) {
      if (stacks[i].indexOf(filterPath) === -1) {
        break;
      }
    }
    for (let j = i;j < stacks.length; ++j) {
      lines += `
` + stacks[j];
    }
    if (error.stack) {
      const pos = error.stack.indexOf(`
`);
      error.stack = error.stack.slice(0, pos) + lines;
    }
    return error;
  }
  exports.optimizeErrorStack = optimizeErrorStack;
  function parseURL(url) {
    if (isInt(url)) {
      return { port: url };
    }
    let parsed = (0, url_1.parse)(url, true, true);
    if (!parsed.slashes && url[0] !== "/") {
      url = "//" + url;
      parsed = (0, url_1.parse)(url, true, true);
    }
    const options = parsed.query || {};
    const result = {};
    if (parsed.auth) {
      const index = parsed.auth.indexOf(":");
      result.username = index === -1 ? parsed.auth : parsed.auth.slice(0, index);
      result.password = index === -1 ? "" : parsed.auth.slice(index + 1);
    }
    if (parsed.pathname) {
      if (parsed.protocol === "redis:" || parsed.protocol === "rediss:") {
        if (parsed.pathname.length > 1) {
          result.db = parsed.pathname.slice(1);
        }
      } else {
        result.path = parsed.pathname;
      }
    }
    if (parsed.host) {
      result.host = parsed.hostname;
    }
    if (parsed.port) {
      result.port = parsed.port;
    }
    if (typeof options.family === "string") {
      const intFamily = Number.parseInt(options.family, 10);
      if (!Number.isNaN(intFamily)) {
        result.family = intFamily;
      }
    }
    (0, lodash_1.defaults)(result, options);
    return result;
  }
  exports.parseURL = parseURL;
  function resolveTLSProfile(options) {
    let tls = options === null || options === undefined ? undefined : options.tls;
    if (typeof tls === "string")
      tls = { profile: tls };
    const profile = TLSProfiles_1.default[tls === null || tls === undefined ? undefined : tls.profile];
    if (profile) {
      tls = Object.assign({}, profile, tls);
      delete tls.profile;
      options = Object.assign({}, options, { tls });
    }
    return options;
  }
  exports.resolveTLSProfile = resolveTLSProfile;
  function sample(array, from = 0) {
    const length = array.length;
    if (from >= length) {
      return null;
    }
    return array[from + Math.floor(Math.random() * (length - from))];
  }
  exports.sample = sample;
  function shuffle(array) {
    let counter = array.length;
    while (counter > 0) {
      const index = Math.floor(Math.random() * counter);
      counter--;
      [array[counter], array[index]] = [array[index], array[counter]];
    }
    return array;
  }
  exports.shuffle = shuffle;
  exports.CONNECTION_CLOSED_ERROR_MSG = "Connection is closed.";
  function zipMap(keys, values) {
    const map = new Map;
    keys.forEach((key, index) => {
      map.set(key, values[index]);
    });
    return map;
  }
  exports.zipMap = zipMap;
  var cachedPackageMeta = null;
  async function getPackageMeta() {
    if (cachedPackageMeta) {
      return cachedPackageMeta;
    }
    try {
      const filePath = (0, path_1.resolve)(__dirname, "..", "..", "package.json");
      const data = await fs_1.promises.readFile(filePath, "utf8");
      const parsed = JSON.parse(data);
      cachedPackageMeta = {
        version: parsed.version
      };
      return cachedPackageMeta;
    } catch (err) {
      cachedPackageMeta = {
        version: "error-fetching-version"
      };
      return cachedPackageMeta;
    }
  }
  exports.getPackageMeta = getPackageMeta;
});

// node_modules/ioredis/built/utils/argumentParsers.js
var require_argumentParsers = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.parseBlockOption = exports.parseSecondsArgument = undefined;
  var parseNumberArgument = (arg) => {
    if (typeof arg === "number") {
      return arg;
    }
    if (Buffer.isBuffer(arg)) {
      return parseNumberArgument(arg.toString());
    }
    if (typeof arg === "string") {
      const value = Number(arg);
      return Number.isFinite(value) ? value : undefined;
    }
    return;
  };
  var parseStringArgument = (arg) => {
    if (typeof arg === "string") {
      return arg;
    }
    if (Buffer.isBuffer(arg)) {
      return arg.toString();
    }
    return;
  };
  var parseSecondsArgument = (arg) => {
    const value = parseNumberArgument(arg);
    if (value === undefined) {
      return;
    }
    if (value <= 0) {
      return 0;
    }
    return value * 1000;
  };
  exports.parseSecondsArgument = parseSecondsArgument;
  var parseBlockOption = (args) => {
    for (let i = 0;i < args.length; i++) {
      const token = parseStringArgument(args[i]);
      if (token && token.toLowerCase() === "block") {
        const duration = parseNumberArgument(args[i + 1]);
        if (duration === undefined) {
          return;
        }
        if (duration <= 0) {
          return 0;
        }
        return duration;
      }
    }
    return null;
  };
  exports.parseBlockOption = parseBlockOption;
});

// node_modules/ioredis/built/Command.js
var require_Command = __commonJS((exports) => {
  var __dirname = "C:\\Users\\JavierEguren\\Desktop\\EntityWars\\entity-wars\\backend\\node_modules\\ioredis\\built";
  Object.defineProperty(exports, "__esModule", { value: true });
  var commands_1 = require_built();
  var calculateSlot = require_lib();
  var standard_as_callback_1 = require_built2();
  var utils_1 = require_utils2();
  var argumentParsers_1 = require_argumentParsers();

  class Command {
    constructor(name, args = [], options = {}, callback) {
      this.name = name;
      this.inTransaction = false;
      this.isResolved = false;
      this.transformed = false;
      this.replyEncoding = options.replyEncoding;
      this.errorStack = options.errorStack;
      this.args = args.flat();
      this.callback = callback;
      this.initPromise();
      if (options.keyPrefix) {
        const isBufferKeyPrefix = options.keyPrefix instanceof Buffer;
        let keyPrefixBuffer = isBufferKeyPrefix ? options.keyPrefix : null;
        this._iterateKeys((key) => {
          if (key instanceof Buffer) {
            if (keyPrefixBuffer === null) {
              keyPrefixBuffer = Buffer.from(options.keyPrefix);
            }
            return Buffer.concat([keyPrefixBuffer, key]);
          } else if (isBufferKeyPrefix) {
            return Buffer.concat([options.keyPrefix, Buffer.from(String(key))]);
          }
          return options.keyPrefix + key;
        });
      }
      if (options.readOnly) {
        this.isReadOnly = true;
      }
    }
    static checkFlag(flagName, commandName) {
      commandName = commandName.toLowerCase();
      return !!this.getFlagMap()[flagName][commandName];
    }
    static setArgumentTransformer(name, func) {
      this._transformer.argument[name] = func;
    }
    static setReplyTransformer(name, func) {
      this._transformer.reply[name] = func;
    }
    static getFlagMap() {
      if (!this.flagMap) {
        this.flagMap = Object.keys(Command.FLAGS).reduce((map, flagName) => {
          map[flagName] = {};
          Command.FLAGS[flagName].forEach((commandName) => {
            map[flagName][commandName] = true;
          });
          return map;
        }, {});
      }
      return this.flagMap;
    }
    getSlot() {
      if (typeof this.slot === "undefined") {
        const key = this.getKeys()[0];
        this.slot = key == null ? null : calculateSlot(key);
      }
      return this.slot;
    }
    getKeys() {
      return this._iterateKeys();
    }
    toWritable(_socket) {
      let result;
      const commandStr = "*" + (this.args.length + 1) + `\r
$` + Buffer.byteLength(this.name) + `\r
` + this.name + `\r
`;
      if (this.bufferMode) {
        const buffers = new MixedBuffers;
        buffers.push(commandStr);
        for (let i = 0;i < this.args.length; ++i) {
          const arg = this.args[i];
          if (arg instanceof Buffer) {
            if (arg.length === 0) {
              buffers.push(`$0\r
\r
`);
            } else {
              buffers.push("$" + arg.length + `\r
`);
              buffers.push(arg);
              buffers.push(`\r
`);
            }
          } else {
            buffers.push("$" + Buffer.byteLength(arg) + `\r
` + arg + `\r
`);
          }
        }
        result = buffers.toBuffer();
      } else {
        result = commandStr;
        for (let i = 0;i < this.args.length; ++i) {
          const arg = this.args[i];
          result += "$" + Buffer.byteLength(arg) + `\r
` + arg + `\r
`;
        }
      }
      return result;
    }
    stringifyArguments() {
      for (let i = 0;i < this.args.length; ++i) {
        const arg = this.args[i];
        if (typeof arg === "string") {} else if (arg instanceof Buffer) {
          this.bufferMode = true;
        } else {
          this.args[i] = (0, utils_1.toArg)(arg);
        }
      }
    }
    transformReply(result) {
      if (this.replyEncoding) {
        result = (0, utils_1.convertBufferToString)(result, this.replyEncoding);
      }
      const transformer = Command._transformer.reply[this.name];
      if (transformer) {
        result = transformer(result);
      }
      return result;
    }
    setTimeout(ms) {
      if (!this._commandTimeoutTimer) {
        this._commandTimeoutTimer = setTimeout(() => {
          if (!this.isResolved) {
            this.reject(new Error("Command timed out"));
          }
        }, ms);
      }
    }
    setBlockingTimeout(ms) {
      if (ms <= 0) {
        return;
      }
      if (this._blockingTimeoutTimer) {
        clearTimeout(this._blockingTimeoutTimer);
        this._blockingTimeoutTimer = undefined;
      }
      const now = Date.now();
      if (this._blockingDeadline === undefined) {
        this._blockingDeadline = now + ms;
      }
      const remaining = this._blockingDeadline - now;
      if (remaining <= 0) {
        this.resolve(null);
        return;
      }
      this._blockingTimeoutTimer = setTimeout(() => {
        if (this.isResolved) {
          this._blockingTimeoutTimer = undefined;
          return;
        }
        this._blockingTimeoutTimer = undefined;
        this.resolve(null);
      }, remaining);
    }
    extractBlockingTimeout() {
      const args = this.args;
      if (!args || args.length === 0) {
        return;
      }
      const name = this.name.toLowerCase();
      if (Command.checkFlag("LAST_ARG_TIMEOUT_COMMANDS", name)) {
        return (0, argumentParsers_1.parseSecondsArgument)(args[args.length - 1]);
      }
      if (Command.checkFlag("FIRST_ARG_TIMEOUT_COMMANDS", name)) {
        return (0, argumentParsers_1.parseSecondsArgument)(args[0]);
      }
      if (Command.checkFlag("BLOCK_OPTION_COMMANDS", name)) {
        return (0, argumentParsers_1.parseBlockOption)(args);
      }
      return;
    }
    _clearTimers() {
      const existingTimer = this._commandTimeoutTimer;
      if (existingTimer) {
        clearTimeout(existingTimer);
        delete this._commandTimeoutTimer;
      }
      const blockingTimer = this._blockingTimeoutTimer;
      if (blockingTimer) {
        clearTimeout(blockingTimer);
        delete this._blockingTimeoutTimer;
      }
    }
    initPromise() {
      const promise = new Promise((resolve, reject) => {
        if (!this.transformed) {
          this.transformed = true;
          const transformer = Command._transformer.argument[this.name];
          if (transformer) {
            this.args = transformer(this.args);
          }
          this.stringifyArguments();
        }
        this.resolve = this._convertValue(resolve);
        this.reject = (err) => {
          this._clearTimers();
          if (this.errorStack) {
            reject((0, utils_1.optimizeErrorStack)(err, this.errorStack.stack, __dirname));
          } else {
            reject(err);
          }
        };
      });
      this.promise = (0, standard_as_callback_1.default)(promise, this.callback);
    }
    _iterateKeys(transform = (key) => key) {
      if (typeof this.keys === "undefined") {
        this.keys = [];
        if ((0, commands_1.exists)(this.name, { caseInsensitive: true })) {
          const keyIndexes = (0, commands_1.getKeyIndexes)(this.name, this.args, {
            nameCaseInsensitive: true
          });
          for (const index of keyIndexes) {
            this.args[index] = transform(this.args[index]);
            this.keys.push(this.args[index]);
          }
        }
      }
      return this.keys;
    }
    _convertValue(resolve) {
      return (value) => {
        try {
          this._clearTimers();
          resolve(this.transformReply(value));
          this.isResolved = true;
        } catch (err) {
          this.reject(err);
        }
        return this.promise;
      };
    }
  }
  exports.default = Command;
  Command.FLAGS = {
    VALID_IN_SUBSCRIBER_MODE: [
      "subscribe",
      "psubscribe",
      "unsubscribe",
      "punsubscribe",
      "ssubscribe",
      "sunsubscribe",
      "ping",
      "quit"
    ],
    VALID_IN_MONITOR_MODE: ["monitor", "auth"],
    ENTER_SUBSCRIBER_MODE: ["subscribe", "psubscribe", "ssubscribe"],
    EXIT_SUBSCRIBER_MODE: ["unsubscribe", "punsubscribe", "sunsubscribe"],
    WILL_DISCONNECT: ["quit"],
    HANDSHAKE_COMMANDS: ["auth", "select", "client", "readonly", "info"],
    IGNORE_RECONNECT_ON_ERROR: ["client"],
    BLOCKING_COMMANDS: [
      "blpop",
      "brpop",
      "brpoplpush",
      "blmove",
      "bzpopmin",
      "bzpopmax",
      "bzmpop",
      "blmpop",
      "xread",
      "xreadgroup"
    ],
    LAST_ARG_TIMEOUT_COMMANDS: [
      "blpop",
      "brpop",
      "brpoplpush",
      "blmove",
      "bzpopmin",
      "bzpopmax"
    ],
    FIRST_ARG_TIMEOUT_COMMANDS: ["bzmpop", "blmpop"],
    BLOCK_OPTION_COMMANDS: ["xread", "xreadgroup"]
  };
  Command._transformer = {
    argument: {},
    reply: {}
  };
  var msetArgumentTransformer = function(args) {
    if (args.length === 1) {
      if (args[0] instanceof Map) {
        return (0, utils_1.convertMapToArray)(args[0]);
      }
      if (typeof args[0] === "object" && args[0] !== null) {
        return (0, utils_1.convertObjectToArray)(args[0]);
      }
    }
    return args;
  };
  var hsetArgumentTransformer = function(args) {
    if (args.length === 2) {
      if (args[1] instanceof Map) {
        return [args[0]].concat((0, utils_1.convertMapToArray)(args[1]));
      }
      if (typeof args[1] === "object" && args[1] !== null) {
        return [args[0]].concat((0, utils_1.convertObjectToArray)(args[1]));
      }
    }
    return args;
  };
  Command.setArgumentTransformer("mset", msetArgumentTransformer);
  Command.setArgumentTransformer("msetnx", msetArgumentTransformer);
  Command.setArgumentTransformer("hset", hsetArgumentTransformer);
  Command.setArgumentTransformer("hmset", hsetArgumentTransformer);
  Command.setReplyTransformer("hgetall", function(result) {
    if (Array.isArray(result)) {
      const obj = {};
      for (let i = 0;i < result.length; i += 2) {
        const key = result[i];
        const value = result[i + 1];
        if (key in obj) {
          Object.defineProperty(obj, key, {
            value,
            configurable: true,
            enumerable: true,
            writable: true
          });
        } else {
          obj[key] = value;
        }
      }
      return obj;
    }
    return result;
  });

  class MixedBuffers {
    constructor() {
      this.length = 0;
      this.items = [];
    }
    push(x) {
      this.length += Buffer.byteLength(x);
      this.items.push(x);
    }
    toBuffer() {
      const result = Buffer.allocUnsafe(this.length);
      let offset = 0;
      for (const item of this.items) {
        const length = Buffer.byteLength(item);
        Buffer.isBuffer(item) ? item.copy(result, offset) : result.write(item, offset, length);
        offset += length;
      }
      return result;
    }
  }
});

// node_modules/ioredis/built/errors/ClusterAllFailedError.js
var require_ClusterAllFailedError = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var redis_errors_1 = require_redis_errors();

  class ClusterAllFailedError extends redis_errors_1.RedisError {
    constructor(message, lastNodeError) {
      super(message);
      this.lastNodeError = lastNodeError;
      Error.captureStackTrace(this, this.constructor);
    }
    get name() {
      return this.constructor.name;
    }
  }
  exports.default = ClusterAllFailedError;
  ClusterAllFailedError.defaultMessage = "Failed to refresh slots cache.";
});

// node_modules/ioredis/built/ScanStream.js
var require_ScanStream = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var stream_1 = __require("stream");

  class ScanStream extends stream_1.Readable {
    constructor(opt) {
      super(opt);
      this.opt = opt;
      this._redisCursor = "0";
      this._redisDrained = false;
    }
    _read() {
      if (this._redisDrained) {
        this.push(null);
        return;
      }
      const args = [this._redisCursor];
      if (this.opt.key) {
        args.unshift(this.opt.key);
      }
      if (this.opt.match) {
        args.push("MATCH", this.opt.match);
      }
      if (this.opt.type) {
        args.push("TYPE", this.opt.type);
      }
      if (this.opt.count) {
        args.push("COUNT", String(this.opt.count));
      }
      if (this.opt.noValues) {
        args.push("NOVALUES");
      }
      this.opt.redis[this.opt.command](args, (err, res) => {
        if (err) {
          this.emit("error", err);
          return;
        }
        this._redisCursor = res[0] instanceof Buffer ? res[0].toString() : res[0];
        if (this._redisCursor === "0") {
          this._redisDrained = true;
        }
        this.push(res[1]);
      });
    }
    close() {
      this._redisDrained = true;
    }
  }
  exports.default = ScanStream;
});

// node_modules/ioredis/built/autoPipelining.js
var require_autoPipelining = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.executeWithAutoPipelining = exports.getFirstValueInFlattenedArray = exports.shouldUseAutoPipelining = exports.notAllowedAutoPipelineCommands = exports.kCallbacks = exports.kExec = undefined;
  var lodash_1 = require_lodash3();
  var calculateSlot = require_lib();
  var standard_as_callback_1 = require_built2();
  exports.kExec = Symbol("exec");
  exports.kCallbacks = Symbol("callbacks");
  exports.notAllowedAutoPipelineCommands = [
    "auth",
    "info",
    "script",
    "quit",
    "cluster",
    "pipeline",
    "multi",
    "subscribe",
    "psubscribe",
    "unsubscribe",
    "unpsubscribe",
    "select",
    "client"
  ];
  function executeAutoPipeline(client, slotKey) {
    if (client._runningAutoPipelines.has(slotKey)) {
      return;
    }
    if (!client._autoPipelines.has(slotKey)) {
      return;
    }
    client._runningAutoPipelines.add(slotKey);
    const pipeline = client._autoPipelines.get(slotKey);
    client._autoPipelines.delete(slotKey);
    const callbacks = pipeline[exports.kCallbacks];
    pipeline[exports.kCallbacks] = null;
    pipeline.exec(function(err, results) {
      client._runningAutoPipelines.delete(slotKey);
      if (err) {
        for (let i = 0;i < callbacks.length; i++) {
          process.nextTick(callbacks[i], err);
        }
      } else {
        for (let i = 0;i < callbacks.length; i++) {
          process.nextTick(callbacks[i], ...results[i]);
        }
      }
      if (client._autoPipelines.has(slotKey)) {
        executeAutoPipeline(client, slotKey);
      }
    });
  }
  function shouldUseAutoPipelining(client, functionName, commandName) {
    return functionName && client.options.enableAutoPipelining && !client.isPipeline && !exports.notAllowedAutoPipelineCommands.includes(commandName) && !client.options.autoPipeliningIgnoredCommands.includes(commandName);
  }
  exports.shouldUseAutoPipelining = shouldUseAutoPipelining;
  function getFirstValueInFlattenedArray(args) {
    for (let i = 0;i < args.length; i++) {
      const arg = args[i];
      if (typeof arg === "string") {
        return arg;
      } else if (Array.isArray(arg) || (0, lodash_1.isArguments)(arg)) {
        if (arg.length === 0) {
          continue;
        }
        return arg[0];
      }
      const flattened = [arg].flat();
      if (flattened.length > 0) {
        return flattened[0];
      }
    }
    return;
  }
  exports.getFirstValueInFlattenedArray = getFirstValueInFlattenedArray;
  function executeWithAutoPipelining(client, functionName, commandName, args, callback) {
    if (client.isCluster && !client.slots.length) {
      if (client.status === "wait")
        client.connect().catch(lodash_1.noop);
      return (0, standard_as_callback_1.default)(new Promise(function(resolve, reject) {
        client.delayUntilReady((err) => {
          if (err) {
            reject(err);
            return;
          }
          executeWithAutoPipelining(client, functionName, commandName, args, null).then(resolve, reject);
        });
      }), callback);
    }
    const prefix = client.options.keyPrefix || "";
    const slotKey = client.isCluster ? client.slots[calculateSlot(`${prefix}${getFirstValueInFlattenedArray(args)}`)].join(",") : "main";
    if (!client._autoPipelines.has(slotKey)) {
      const pipeline2 = client.pipeline();
      pipeline2[exports.kExec] = false;
      pipeline2[exports.kCallbacks] = [];
      client._autoPipelines.set(slotKey, pipeline2);
    }
    const pipeline = client._autoPipelines.get(slotKey);
    if (!pipeline[exports.kExec]) {
      pipeline[exports.kExec] = true;
      setImmediate(executeAutoPipeline, client, slotKey);
    }
    const autoPipelinePromise = new Promise(function(resolve, reject) {
      pipeline[exports.kCallbacks].push(function(err, value) {
        if (err) {
          reject(err);
          return;
        }
        resolve(value);
      });
      if (functionName === "call") {
        args.unshift(commandName);
      }
      pipeline[functionName](...args);
    });
    return (0, standard_as_callback_1.default)(autoPipelinePromise, callback);
  }
  exports.executeWithAutoPipelining = executeWithAutoPipelining;
});

// node_modules/ioredis/built/Script.js
var require_Script = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var crypto_1 = __require("crypto");
  var Command_1 = require_Command();
  var standard_as_callback_1 = require_built2();

  class Script {
    constructor(lua, numberOfKeys = null, keyPrefix = "", readOnly = false) {
      this.lua = lua;
      this.numberOfKeys = numberOfKeys;
      this.keyPrefix = keyPrefix;
      this.readOnly = readOnly;
      this.sha = (0, crypto_1.createHash)("sha1").update(lua).digest("hex");
      const sha = this.sha;
      const socketHasScriptLoaded = new WeakSet;
      this.Command = class CustomScriptCommand extends Command_1.default {
        toWritable(socket) {
          const origReject = this.reject;
          this.reject = (err) => {
            if (err.message.indexOf("NOSCRIPT") !== -1) {
              socketHasScriptLoaded.delete(socket);
            }
            origReject.call(this, err);
          };
          if (!socketHasScriptLoaded.has(socket)) {
            socketHasScriptLoaded.add(socket);
            this.name = "eval";
            this.args[0] = lua;
          } else if (this.name === "eval") {
            this.name = "evalsha";
            this.args[0] = sha;
          }
          return super.toWritable(socket);
        }
      };
    }
    execute(container, args, options, callback) {
      if (typeof this.numberOfKeys === "number") {
        args.unshift(this.numberOfKeys);
      }
      if (this.keyPrefix) {
        options.keyPrefix = this.keyPrefix;
      }
      if (this.readOnly) {
        options.readOnly = true;
      }
      const evalsha = new this.Command("evalsha", [this.sha, ...args], options);
      evalsha.promise = evalsha.promise.catch((err) => {
        if (err.message.indexOf("NOSCRIPT") === -1) {
          throw err;
        }
        const resend = new this.Command("evalsha", [this.sha, ...args], options);
        const client = container.isPipeline ? container.redis : container;
        return client.sendCommand(resend);
      });
      (0, standard_as_callback_1.default)(evalsha.promise, callback);
      return container.sendCommand(evalsha);
    }
  }
  exports.default = Script;
});

// node_modules/ioredis/built/utils/Commander.js
var require_Commander = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var commands_1 = require_built();
  var autoPipelining_1 = require_autoPipelining();
  var Command_1 = require_Command();
  var Script_1 = require_Script();

  class Commander {
    constructor() {
      this.options = {};
      this.scriptsSet = {};
      this.addedBuiltinSet = new Set;
    }
    getBuiltinCommands() {
      return commands.slice(0);
    }
    createBuiltinCommand(commandName) {
      return {
        string: generateFunction(null, commandName, "utf8"),
        buffer: generateFunction(null, commandName, null)
      };
    }
    addBuiltinCommand(commandName) {
      this.addedBuiltinSet.add(commandName);
      this[commandName] = generateFunction(commandName, commandName, "utf8");
      this[commandName + "Buffer"] = generateFunction(commandName + "Buffer", commandName, null);
    }
    defineCommand(name, definition) {
      const script = new Script_1.default(definition.lua, definition.numberOfKeys, this.options.keyPrefix, definition.readOnly);
      this.scriptsSet[name] = script;
      this[name] = generateScriptingFunction(name, name, script, "utf8");
      this[name + "Buffer"] = generateScriptingFunction(name + "Buffer", name, script, null);
    }
    sendCommand(command, stream, node) {
      throw new Error('"sendCommand" is not implemented');
    }
  }
  var commands = commands_1.list.filter((command) => command !== "monitor");
  commands.push("sentinel");
  commands.forEach(function(commandName) {
    Commander.prototype[commandName] = generateFunction(commandName, commandName, "utf8");
    Commander.prototype[commandName + "Buffer"] = generateFunction(commandName + "Buffer", commandName, null);
  });
  Commander.prototype.call = generateFunction("call", "utf8");
  Commander.prototype.callBuffer = generateFunction("callBuffer", null);
  Commander.prototype.send_command = Commander.prototype.call;
  function generateFunction(functionName, _commandName, _encoding) {
    if (typeof _encoding === "undefined") {
      _encoding = _commandName;
      _commandName = null;
    }
    return function(...args) {
      const commandName = _commandName || args.shift();
      let callback = args[args.length - 1];
      if (typeof callback === "function") {
        args.pop();
      } else {
        callback = undefined;
      }
      const options = {
        errorStack: this.options.showFriendlyErrorStack ? new Error : undefined,
        keyPrefix: this.options.keyPrefix,
        replyEncoding: _encoding
      };
      if (!(0, autoPipelining_1.shouldUseAutoPipelining)(this, functionName, commandName)) {
        return this.sendCommand(new Command_1.default(commandName, args, options, callback));
      }
      return (0, autoPipelining_1.executeWithAutoPipelining)(this, functionName, commandName, args, callback);
    };
  }
  function generateScriptingFunction(functionName, commandName, script, encoding) {
    return function(...args) {
      const callback = typeof args[args.length - 1] === "function" ? args.pop() : undefined;
      const options = {
        replyEncoding: encoding
      };
      if (this.options.showFriendlyErrorStack) {
        options.errorStack = new Error;
      }
      if (!(0, autoPipelining_1.shouldUseAutoPipelining)(this, functionName, commandName)) {
        return script.execute(this, args, options, callback);
      }
      return (0, autoPipelining_1.executeWithAutoPipelining)(this, functionName, commandName, args, callback);
    };
  }
  exports.default = Commander;
});

// node_modules/ioredis/built/Pipeline.js
var require_Pipeline = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var calculateSlot = require_lib();
  var commands_1 = require_built();
  var standard_as_callback_1 = require_built2();
  var util_1 = __require("util");
  var Command_1 = require_Command();
  var utils_1 = require_utils2();
  var Commander_1 = require_Commander();
  function generateMultiWithNodes(redis, keys) {
    const slot = calculateSlot(keys[0]);
    const target = redis._groupsBySlot[slot];
    for (let i = 1;i < keys.length; i++) {
      if (redis._groupsBySlot[calculateSlot(keys[i])] !== target) {
        return -1;
      }
    }
    return slot;
  }

  class Pipeline extends Commander_1.default {
    constructor(redis) {
      super();
      this.redis = redis;
      this.isPipeline = true;
      this.replyPending = 0;
      this._queue = [];
      this._result = [];
      this._transactions = 0;
      this._shaToScript = {};
      this.isCluster = this.redis.constructor.name === "Cluster" || this.redis.isCluster;
      this.options = redis.options;
      Object.keys(redis.scriptsSet).forEach((name) => {
        const script = redis.scriptsSet[name];
        this._shaToScript[script.sha] = script;
        this[name] = redis[name];
        this[name + "Buffer"] = redis[name + "Buffer"];
      });
      redis.addedBuiltinSet.forEach((name) => {
        this[name] = redis[name];
        this[name + "Buffer"] = redis[name + "Buffer"];
      });
      this.promise = new Promise((resolve, reject) => {
        this.resolve = resolve;
        this.reject = reject;
      });
      const _this = this;
      Object.defineProperty(this, "length", {
        get: function() {
          return _this._queue.length;
        }
      });
    }
    fillResult(value, position) {
      if (this._queue[position].name === "exec" && Array.isArray(value[1])) {
        const execLength = value[1].length;
        for (let i = 0;i < execLength; i++) {
          if (value[1][i] instanceof Error) {
            continue;
          }
          const cmd = this._queue[position - (execLength - i)];
          try {
            value[1][i] = cmd.transformReply(value[1][i]);
          } catch (err) {
            value[1][i] = err;
          }
        }
      }
      this._result[position] = value;
      if (--this.replyPending) {
        return;
      }
      if (this.isCluster) {
        let retriable = true;
        let commonError;
        for (let i = 0;i < this._result.length; ++i) {
          const error = this._result[i][0];
          const command = this._queue[i];
          if (error) {
            if (command.name === "exec" && error.message === "EXECABORT Transaction discarded because of previous errors.") {
              continue;
            }
            if (!commonError) {
              commonError = {
                name: error.name,
                message: error.message
              };
            } else if (commonError.name !== error.name || commonError.message !== error.message) {
              retriable = false;
              break;
            }
          } else if (!command.inTransaction) {
            const isReadOnly = (0, commands_1.exists)(command.name, { caseInsensitive: true }) && (0, commands_1.hasFlag)(command.name, "readonly", { nameCaseInsensitive: true });
            if (!isReadOnly) {
              retriable = false;
              break;
            }
          }
        }
        if (commonError && retriable) {
          const _this = this;
          const errv = commonError.message.split(" ");
          const queue = this._queue;
          let inTransaction = false;
          this._queue = [];
          for (let i = 0;i < queue.length; ++i) {
            if (errv[0] === "ASK" && !inTransaction && queue[i].name !== "asking" && (!queue[i - 1] || queue[i - 1].name !== "asking")) {
              const asking = new Command_1.default("asking");
              asking.ignore = true;
              this.sendCommand(asking);
            }
            queue[i].initPromise();
            this.sendCommand(queue[i]);
            inTransaction = queue[i].inTransaction;
          }
          let matched = true;
          if (typeof this.leftRedirections === "undefined") {
            this.leftRedirections = {};
          }
          const exec = function() {
            _this.exec();
          };
          const cluster = this.redis;
          cluster.handleError(commonError, this.leftRedirections, {
            moved: function(_slot, key) {
              _this.preferKey = key;
              cluster.slots[errv[1]] = [key];
              cluster._groupsBySlot[errv[1]] = cluster._groupsIds[cluster.slots[errv[1]].join(";")];
              cluster.refreshSlotsCache();
              _this.exec();
            },
            ask: function(_slot, key) {
              _this.preferKey = key;
              _this.exec();
            },
            tryagain: exec,
            clusterDown: exec,
            connectionClosed: exec,
            maxRedirections: () => {
              matched = false;
            },
            defaults: () => {
              matched = false;
            }
          });
          if (matched) {
            return;
          }
        }
      }
      let ignoredCount = 0;
      for (let i = 0;i < this._queue.length - ignoredCount; ++i) {
        if (this._queue[i + ignoredCount].ignore) {
          ignoredCount += 1;
        }
        this._result[i] = this._result[i + ignoredCount];
      }
      this.resolve(this._result.slice(0, this._result.length - ignoredCount));
    }
    sendCommand(command) {
      if (this._transactions > 0) {
        command.inTransaction = true;
      }
      const position = this._queue.length;
      command.pipelineIndex = position;
      command.promise.then((result) => {
        this.fillResult([null, result], position);
      }).catch((error) => {
        this.fillResult([error], position);
      });
      this._queue.push(command);
      return this;
    }
    addBatch(commands) {
      let command, commandName, args;
      for (let i = 0;i < commands.length; ++i) {
        command = commands[i];
        commandName = command[0];
        args = command.slice(1);
        this[commandName].apply(this, args);
      }
      return this;
    }
  }
  exports.default = Pipeline;
  var multi = Pipeline.prototype.multi;
  Pipeline.prototype.multi = function() {
    this._transactions += 1;
    return multi.apply(this, arguments);
  };
  var execBuffer = Pipeline.prototype.execBuffer;
  Pipeline.prototype.execBuffer = (0, util_1.deprecate)(function() {
    if (this._transactions > 0) {
      this._transactions -= 1;
    }
    return execBuffer.apply(this, arguments);
  }, "Pipeline#execBuffer: Use Pipeline#exec instead");
  Pipeline.prototype.exec = function(callback) {
    if (this.isCluster && !this.redis.slots.length) {
      if (this.redis.status === "wait")
        this.redis.connect().catch(utils_1.noop);
      if (callback && !this.nodeifiedPromise) {
        this.nodeifiedPromise = true;
        (0, standard_as_callback_1.default)(this.promise, callback);
      }
      this.redis.delayUntilReady((err) => {
        if (err) {
          this.reject(err);
          return;
        }
        this.exec(callback);
      });
      return this.promise;
    }
    if (this._transactions > 0) {
      this._transactions -= 1;
      return execBuffer.apply(this, arguments);
    }
    if (!this.nodeifiedPromise) {
      this.nodeifiedPromise = true;
      (0, standard_as_callback_1.default)(this.promise, callback);
    }
    if (!this._queue.length) {
      this.resolve([]);
    }
    let pipelineSlot;
    if (this.isCluster) {
      const sampleKeys = [];
      for (let i = 0;i < this._queue.length; i++) {
        const keys = this._queue[i].getKeys();
        if (keys.length) {
          sampleKeys.push(keys[0]);
        }
        if (keys.length && calculateSlot.generateMulti(keys) < 0) {
          this.reject(new Error("All the keys in a pipeline command should belong to the same slot"));
          return this.promise;
        }
      }
      if (sampleKeys.length) {
        pipelineSlot = generateMultiWithNodes(this.redis, sampleKeys);
        if (pipelineSlot < 0) {
          this.reject(new Error("All keys in the pipeline should belong to the same slots allocation group"));
          return this.promise;
        }
      } else {
        pipelineSlot = Math.random() * 16384 | 0;
      }
    }
    const _this = this;
    execPipeline();
    return this.promise;
    function execPipeline() {
      let writePending = _this.replyPending = _this._queue.length;
      let node;
      if (_this.isCluster) {
        node = {
          slot: pipelineSlot,
          redis: _this.redis.connectionPool.nodes.all[_this.preferKey]
        };
      }
      let data = "";
      let buffers;
      const stream = {
        isPipeline: true,
        destination: _this.isCluster ? node : { redis: _this.redis },
        write(writable) {
          if (typeof writable !== "string") {
            if (!buffers) {
              buffers = [];
            }
            if (data) {
              buffers.push(Buffer.from(data, "utf8"));
              data = "";
            }
            buffers.push(writable);
          } else {
            data += writable;
          }
          if (!--writePending) {
            if (buffers) {
              if (data) {
                buffers.push(Buffer.from(data, "utf8"));
              }
              stream.destination.redis.stream.write(Buffer.concat(buffers));
            } else {
              stream.destination.redis.stream.write(data);
            }
            writePending = _this._queue.length;
            data = "";
            buffers = undefined;
          }
        }
      };
      for (let i = 0;i < _this._queue.length; ++i) {
        _this.redis.sendCommand(_this._queue[i], stream, node);
      }
      return _this.promise;
    }
  };
});

// node_modules/ioredis/built/transaction.js
var require_transaction = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.addTransactionSupport = undefined;
  var utils_1 = require_utils2();
  var standard_as_callback_1 = require_built2();
  var Pipeline_1 = require_Pipeline();
  function addTransactionSupport(redis) {
    redis.pipeline = function(commands) {
      const pipeline = new Pipeline_1.default(this);
      if (Array.isArray(commands)) {
        pipeline.addBatch(commands);
      }
      return pipeline;
    };
    const { multi } = redis;
    redis.multi = function(commands, options) {
      if (typeof options === "undefined" && !Array.isArray(commands)) {
        options = commands;
        commands = null;
      }
      if (options && options.pipeline === false) {
        return multi.call(this);
      }
      const pipeline = new Pipeline_1.default(this);
      pipeline.multi();
      if (Array.isArray(commands)) {
        pipeline.addBatch(commands);
      }
      const exec2 = pipeline.exec;
      pipeline.exec = function(callback) {
        if (this.isCluster && !this.redis.slots.length) {
          if (this.redis.status === "wait")
            this.redis.connect().catch(utils_1.noop);
          return (0, standard_as_callback_1.default)(new Promise((resolve, reject) => {
            this.redis.delayUntilReady((err) => {
              if (err) {
                reject(err);
                return;
              }
              this.exec(pipeline).then(resolve, reject);
            });
          }), callback);
        }
        if (this._transactions > 0) {
          exec2.call(pipeline);
        }
        if (this.nodeifiedPromise) {
          return exec2.call(pipeline);
        }
        const promise = exec2.call(pipeline);
        return (0, standard_as_callback_1.default)(promise.then(function(result) {
          const execResult = result[result.length - 1];
          if (typeof execResult === "undefined") {
            throw new Error("Pipeline cannot be used to send any commands when the `exec()` has been called on it.");
          }
          if (execResult[0]) {
            execResult[0].previousErrors = [];
            for (let i = 0;i < result.length - 1; ++i) {
              if (result[i][0]) {
                execResult[0].previousErrors.push(result[i][0]);
              }
            }
            throw execResult[0];
          }
          return (0, utils_1.wrapMultiResult)(execResult[1]);
        }), callback);
      };
      const { execBuffer } = pipeline;
      pipeline.execBuffer = function(callback) {
        if (this._transactions > 0) {
          execBuffer.call(pipeline);
        }
        return pipeline.exec(callback);
      };
      return pipeline;
    };
    const { exec } = redis;
    redis.exec = function(callback) {
      return (0, standard_as_callback_1.default)(exec.call(this).then(function(results) {
        if (Array.isArray(results)) {
          results = (0, utils_1.wrapMultiResult)(results);
        }
        return results;
      }), callback);
    };
  }
  exports.addTransactionSupport = addTransactionSupport;
});

// node_modules/ioredis/built/utils/applyMixin.js
var require_applyMixin = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  function applyMixin(derivedConstructor, mixinConstructor) {
    Object.getOwnPropertyNames(mixinConstructor.prototype).forEach((name) => {
      Object.defineProperty(derivedConstructor.prototype, name, Object.getOwnPropertyDescriptor(mixinConstructor.prototype, name));
    });
  }
  exports.default = applyMixin;
});

// node_modules/ioredis/built/cluster/ClusterOptions.js
var require_ClusterOptions = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.DEFAULT_CLUSTER_OPTIONS = undefined;
  var dns_1 = __require("dns");
  exports.DEFAULT_CLUSTER_OPTIONS = {
    clusterRetryStrategy: (times) => Math.min(100 + times * 2, 2000),
    enableOfflineQueue: true,
    enableReadyCheck: true,
    scaleReads: "master",
    maxRedirections: 16,
    retryDelayOnMoved: 0,
    retryDelayOnFailover: 100,
    retryDelayOnClusterDown: 100,
    retryDelayOnTryAgain: 100,
    slotsRefreshTimeout: 1000,
    useSRVRecords: false,
    resolveSrv: dns_1.resolveSrv,
    dnsLookup: dns_1.lookup,
    enableAutoPipelining: false,
    autoPipeliningIgnoredCommands: [],
    shardedSubscribers: false
  };
});

// node_modules/ioredis/built/cluster/util.js
var require_util = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.getConnectionName = exports.weightSrvRecords = exports.groupSrvRecords = exports.getUniqueHostnamesFromOptions = exports.normalizeNodeOptions = exports.nodeKeyToRedisOptions = exports.getNodeKey = undefined;
  var utils_1 = require_utils2();
  var net_1 = __require("net");
  function getNodeKey(node) {
    node.port = node.port || 6379;
    node.host = node.host || "127.0.0.1";
    return node.host + ":" + node.port;
  }
  exports.getNodeKey = getNodeKey;
  function nodeKeyToRedisOptions(nodeKey) {
    const portIndex = nodeKey.lastIndexOf(":");
    if (portIndex === -1) {
      throw new Error(`Invalid node key ${nodeKey}`);
    }
    return {
      host: nodeKey.slice(0, portIndex),
      port: Number(nodeKey.slice(portIndex + 1))
    };
  }
  exports.nodeKeyToRedisOptions = nodeKeyToRedisOptions;
  function normalizeNodeOptions(nodes) {
    return nodes.map((node) => {
      const options = {};
      if (typeof node === "object") {
        Object.assign(options, node);
      } else if (typeof node === "string") {
        Object.assign(options, (0, utils_1.parseURL)(node));
      } else if (typeof node === "number") {
        options.port = node;
      } else {
        throw new Error("Invalid argument " + node);
      }
      if (typeof options.port === "string") {
        options.port = parseInt(options.port, 10);
      }
      delete options.db;
      if (!options.port) {
        options.port = 6379;
      }
      if (!options.host) {
        options.host = "127.0.0.1";
      }
      return (0, utils_1.resolveTLSProfile)(options);
    });
  }
  exports.normalizeNodeOptions = normalizeNodeOptions;
  function getUniqueHostnamesFromOptions(nodes) {
    const uniqueHostsMap = {};
    nodes.forEach((node) => {
      uniqueHostsMap[node.host] = true;
    });
    return Object.keys(uniqueHostsMap).filter((host) => !(0, net_1.isIP)(host));
  }
  exports.getUniqueHostnamesFromOptions = getUniqueHostnamesFromOptions;
  function groupSrvRecords(records) {
    const recordsByPriority = {};
    for (const record of records) {
      if (!recordsByPriority.hasOwnProperty(record.priority)) {
        recordsByPriority[record.priority] = {
          totalWeight: record.weight,
          records: [record]
        };
      } else {
        recordsByPriority[record.priority].totalWeight += record.weight;
        recordsByPriority[record.priority].records.push(record);
      }
    }
    return recordsByPriority;
  }
  exports.groupSrvRecords = groupSrvRecords;
  function weightSrvRecords(recordsGroup) {
    if (recordsGroup.records.length === 1) {
      recordsGroup.totalWeight = 0;
      return recordsGroup.records.shift();
    }
    const random = Math.floor(Math.random() * (recordsGroup.totalWeight + recordsGroup.records.length));
    let total = 0;
    for (const [i, record] of recordsGroup.records.entries()) {
      total += 1 + record.weight;
      if (total > random) {
        recordsGroup.totalWeight -= record.weight;
        recordsGroup.records.splice(i, 1);
        return record;
      }
    }
  }
  exports.weightSrvRecords = weightSrvRecords;
  function getConnectionName(component, nodeConnectionName) {
    const prefix = `ioredis-cluster(${component})`;
    return nodeConnectionName ? `${prefix}:${nodeConnectionName}` : prefix;
  }
  exports.getConnectionName = getConnectionName;
});

// node_modules/ioredis/built/cluster/ClusterSubscriber.js
var require_ClusterSubscriber = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var util_1 = require_util();
  var utils_1 = require_utils2();
  var Redis_1 = require_Redis();
  var debug = (0, utils_1.Debug)("cluster:subscriber");

  class ClusterSubscriber {
    constructor(connectionPool, emitter, isSharded = false) {
      this.connectionPool = connectionPool;
      this.emitter = emitter;
      this.isSharded = isSharded;
      this.started = false;
      this.subscriber = null;
      this.slotRange = [];
      this.onSubscriberEnd = () => {
        if (!this.started) {
          debug("subscriber has disconnected, but ClusterSubscriber is not started, so not reconnecting.");
          return;
        }
        debug("subscriber has disconnected, selecting a new one...");
        this.selectSubscriber();
      };
      this.connectionPool.on("-node", (_, key) => {
        if (!this.started || !this.subscriber) {
          return;
        }
        if ((0, util_1.getNodeKey)(this.subscriber.options) === key) {
          debug("subscriber has left, selecting a new one...");
          this.selectSubscriber();
        }
      });
      this.connectionPool.on("+node", () => {
        if (!this.started || this.subscriber) {
          return;
        }
        debug("a new node is discovered and there is no subscriber, selecting a new one...");
        this.selectSubscriber();
      });
    }
    getInstance() {
      return this.subscriber;
    }
    associateSlotRange(range) {
      if (this.isSharded) {
        this.slotRange = range;
      }
      return this.slotRange;
    }
    start() {
      this.started = true;
      this.selectSubscriber();
      debug("started");
    }
    stop() {
      this.started = false;
      if (this.subscriber) {
        this.subscriber.disconnect();
        this.subscriber = null;
      }
    }
    isStarted() {
      return this.started;
    }
    selectSubscriber() {
      const lastActiveSubscriber = this.lastActiveSubscriber;
      if (lastActiveSubscriber) {
        lastActiveSubscriber.off("end", this.onSubscriberEnd);
        lastActiveSubscriber.disconnect();
      }
      if (this.subscriber) {
        this.subscriber.off("end", this.onSubscriberEnd);
        this.subscriber.disconnect();
      }
      const sampleNode = (0, utils_1.sample)(this.connectionPool.getNodes());
      if (!sampleNode) {
        debug("selecting subscriber failed since there is no node discovered in the cluster yet");
        this.subscriber = null;
        return;
      }
      const { options } = sampleNode;
      debug("selected a subscriber %s:%s", options.host, options.port);
      let connectionPrefix = "subscriber";
      if (this.isSharded)
        connectionPrefix = "ssubscriber";
      this.subscriber = new Redis_1.default({
        port: options.port,
        host: options.host,
        username: options.username,
        password: options.password,
        enableReadyCheck: true,
        connectionName: (0, util_1.getConnectionName)(connectionPrefix, options.connectionName),
        lazyConnect: true,
        tls: options.tls,
        retryStrategy: null
      });
      this.subscriber.on("error", utils_1.noop);
      this.subscriber.on("moved", () => {
        this.emitter.emit("forceRefresh");
      });
      this.subscriber.once("end", this.onSubscriberEnd);
      const previousChannels = { subscribe: [], psubscribe: [], ssubscribe: [] };
      if (lastActiveSubscriber) {
        const condition = lastActiveSubscriber.condition || lastActiveSubscriber.prevCondition;
        if (condition && condition.subscriber) {
          previousChannels.subscribe = condition.subscriber.channels("subscribe");
          previousChannels.psubscribe = condition.subscriber.channels("psubscribe");
          previousChannels.ssubscribe = condition.subscriber.channels("ssubscribe");
        }
      }
      if (previousChannels.subscribe.length || previousChannels.psubscribe.length || previousChannels.ssubscribe.length) {
        let pending = 0;
        for (const type of ["subscribe", "psubscribe", "ssubscribe"]) {
          const channels = previousChannels[type];
          if (channels.length == 0) {
            continue;
          }
          debug("%s %d channels", type, channels.length);
          if (type === "ssubscribe") {
            for (const channel of channels) {
              pending += 1;
              this.subscriber[type](channel).then(() => {
                if (!--pending) {
                  this.lastActiveSubscriber = this.subscriber;
                }
              }).catch(() => {
                debug("failed to ssubscribe to channel: %s", channel);
              });
            }
          } else {
            pending += 1;
            this.subscriber[type](channels).then(() => {
              if (!--pending) {
                this.lastActiveSubscriber = this.subscriber;
              }
            }).catch(() => {
              debug("failed to %s %d channels", type, channels.length);
            });
          }
        }
      } else {
        this.lastActiveSubscriber = this.subscriber;
      }
      for (const event of [
        "message",
        "messageBuffer"
      ]) {
        this.subscriber.on(event, (arg1, arg2) => {
          this.emitter.emit(event, arg1, arg2);
        });
      }
      for (const event of ["pmessage", "pmessageBuffer"]) {
        this.subscriber.on(event, (arg1, arg2, arg3) => {
          this.emitter.emit(event, arg1, arg2, arg3);
        });
      }
      if (this.isSharded == true) {
        for (const event of [
          "smessage",
          "smessageBuffer"
        ]) {
          this.subscriber.on(event, (arg1, arg2) => {
            this.emitter.emit(event, arg1, arg2);
          });
        }
      }
    }
  }
  exports.default = ClusterSubscriber;
});

// node_modules/ioredis/built/cluster/ConnectionPool.js
var require_ConnectionPool = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var events_1 = __require("events");
  var utils_1 = require_utils2();
  var util_1 = require_util();
  var Redis_1 = require_Redis();
  var debug = (0, utils_1.Debug)("cluster:connectionPool");

  class ConnectionPool extends events_1.EventEmitter {
    constructor(redisOptions) {
      super();
      this.redisOptions = redisOptions;
      this.nodes = {
        all: {},
        master: {},
        slave: {}
      };
      this.specifiedOptions = {};
    }
    getNodes(role = "all") {
      const nodes = this.nodes[role];
      return Object.keys(nodes).map((key) => nodes[key]);
    }
    getInstanceByKey(key) {
      return this.nodes.all[key];
    }
    getSampleInstance(role) {
      const keys = Object.keys(this.nodes[role]);
      const sampleKey = (0, utils_1.sample)(keys);
      return this.nodes[role][sampleKey];
    }
    addMasterNode(node) {
      const key = (0, util_1.getNodeKey)(node.options);
      const redis = this.createRedisFromOptions(node, node.options.readOnly);
      if (!node.options.readOnly) {
        this.nodes.all[key] = redis;
        this.nodes.master[key] = redis;
        return true;
      }
      return false;
    }
    createRedisFromOptions(node, readOnly) {
      const redis = new Redis_1.default((0, utils_1.defaults)({
        retryStrategy: null,
        enableOfflineQueue: true,
        readOnly
      }, node, this.redisOptions, { lazyConnect: true }));
      return redis;
    }
    findOrCreate(node, readOnly = false) {
      const key = (0, util_1.getNodeKey)(node);
      readOnly = Boolean(readOnly);
      if (this.specifiedOptions[key]) {
        Object.assign(node, this.specifiedOptions[key]);
      } else {
        this.specifiedOptions[key] = node;
      }
      let redis;
      if (this.nodes.all[key]) {
        redis = this.nodes.all[key];
        if (redis.options.readOnly !== readOnly) {
          redis.options.readOnly = readOnly;
          debug("Change role of %s to %s", key, readOnly ? "slave" : "master");
          redis[readOnly ? "readonly" : "readwrite"]().catch(utils_1.noop);
          if (readOnly) {
            delete this.nodes.master[key];
            this.nodes.slave[key] = redis;
          } else {
            delete this.nodes.slave[key];
            this.nodes.master[key] = redis;
          }
        }
      } else {
        debug("Connecting to %s as %s", key, readOnly ? "slave" : "master");
        redis = this.createRedisFromOptions(node, readOnly);
        this.nodes.all[key] = redis;
        this.nodes[readOnly ? "slave" : "master"][key] = redis;
        redis.once("end", () => {
          this.removeNode(key);
          this.emit("-node", redis, key);
          if (!Object.keys(this.nodes.all).length) {
            this.emit("drain");
          }
        });
        this.emit("+node", redis, key);
        redis.on("error", function(error) {
          this.emit("nodeError", error, key);
        });
      }
      return redis;
    }
    reset(nodes) {
      debug("Reset with %O", nodes);
      const newNodes = {};
      nodes.forEach((node) => {
        const key = (0, util_1.getNodeKey)(node);
        if (!(node.readOnly && newNodes[key])) {
          newNodes[key] = node;
        }
      });
      Object.keys(this.nodes.all).forEach((key) => {
        if (!newNodes[key]) {
          debug("Disconnect %s because the node does not hold any slot", key);
          this.nodes.all[key].disconnect();
          this.removeNode(key);
        }
      });
      Object.keys(newNodes).forEach((key) => {
        const node = newNodes[key];
        this.findOrCreate(node, node.readOnly);
      });
    }
    removeNode(key) {
      const { nodes } = this;
      if (nodes.all[key]) {
        debug("Remove %s from the pool", key);
        delete nodes.all[key];
      }
      delete nodes.master[key];
      delete nodes.slave[key];
    }
  }
  exports.default = ConnectionPool;
});

// node_modules/denque/index.js
var require_denque = __commonJS((exports, module) => {
  function Denque(array, options) {
    var options = options || {};
    this._capacity = options.capacity;
    this._head = 0;
    this._tail = 0;
    if (Array.isArray(array)) {
      this._fromArray(array);
    } else {
      this._capacityMask = 3;
      this._list = new Array(4);
    }
  }
  Denque.prototype.peekAt = function peekAt(index) {
    var i = index;
    if (i !== (i | 0)) {
      return;
    }
    var len = this.size();
    if (i >= len || i < -len)
      return;
    if (i < 0)
      i += len;
    i = this._head + i & this._capacityMask;
    return this._list[i];
  };
  Denque.prototype.get = function get(i) {
    return this.peekAt(i);
  };
  Denque.prototype.peek = function peek() {
    if (this._head === this._tail)
      return;
    return this._list[this._head];
  };
  Denque.prototype.peekFront = function peekFront() {
    return this.peek();
  };
  Denque.prototype.peekBack = function peekBack() {
    return this.peekAt(-1);
  };
  Object.defineProperty(Denque.prototype, "length", {
    get: function length() {
      return this.size();
    }
  });
  Denque.prototype.size = function size() {
    if (this._head === this._tail)
      return 0;
    if (this._head < this._tail)
      return this._tail - this._head;
    else
      return this._capacityMask + 1 - (this._head - this._tail);
  };
  Denque.prototype.unshift = function unshift(item) {
    if (arguments.length === 0)
      return this.size();
    var len = this._list.length;
    this._head = this._head - 1 + len & this._capacityMask;
    this._list[this._head] = item;
    if (this._tail === this._head)
      this._growArray();
    if (this._capacity && this.size() > this._capacity)
      this.pop();
    if (this._head < this._tail)
      return this._tail - this._head;
    else
      return this._capacityMask + 1 - (this._head - this._tail);
  };
  Denque.prototype.shift = function shift() {
    var head = this._head;
    if (head === this._tail)
      return;
    var item = this._list[head];
    this._list[head] = undefined;
    this._head = head + 1 & this._capacityMask;
    if (head < 2 && this._tail > 1e4 && this._tail <= this._list.length >>> 2)
      this._shrinkArray();
    return item;
  };
  Denque.prototype.push = function push(item) {
    if (arguments.length === 0)
      return this.size();
    var tail = this._tail;
    this._list[tail] = item;
    this._tail = tail + 1 & this._capacityMask;
    if (this._tail === this._head) {
      this._growArray();
    }
    if (this._capacity && this.size() > this._capacity) {
      this.shift();
    }
    if (this._head < this._tail)
      return this._tail - this._head;
    else
      return this._capacityMask + 1 - (this._head - this._tail);
  };
  Denque.prototype.pop = function pop() {
    var tail = this._tail;
    if (tail === this._head)
      return;
    var len = this._list.length;
    this._tail = tail - 1 + len & this._capacityMask;
    var item = this._list[this._tail];
    this._list[this._tail] = undefined;
    if (this._head < 2 && tail > 1e4 && tail <= len >>> 2)
      this._shrinkArray();
    return item;
  };
  Denque.prototype.removeOne = function removeOne(index) {
    var i = index;
    if (i !== (i | 0)) {
      return;
    }
    if (this._head === this._tail)
      return;
    var size = this.size();
    var len = this._list.length;
    if (i >= size || i < -size)
      return;
    if (i < 0)
      i += size;
    i = this._head + i & this._capacityMask;
    var item = this._list[i];
    var k;
    if (index < size / 2) {
      for (k = index;k > 0; k--) {
        this._list[i] = this._list[i = i - 1 + len & this._capacityMask];
      }
      this._list[i] = undefined;
      this._head = this._head + 1 + len & this._capacityMask;
    } else {
      for (k = size - 1 - index;k > 0; k--) {
        this._list[i] = this._list[i = i + 1 + len & this._capacityMask];
      }
      this._list[i] = undefined;
      this._tail = this._tail - 1 + len & this._capacityMask;
    }
    return item;
  };
  Denque.prototype.remove = function remove(index, count) {
    var i = index;
    var removed;
    var del_count = count;
    if (i !== (i | 0)) {
      return;
    }
    if (this._head === this._tail)
      return;
    var size = this.size();
    var len = this._list.length;
    if (i >= size || i < -size || count < 1)
      return;
    if (i < 0)
      i += size;
    if (count === 1 || !count) {
      removed = new Array(1);
      removed[0] = this.removeOne(i);
      return removed;
    }
    if (i === 0 && i + count >= size) {
      removed = this.toArray();
      this.clear();
      return removed;
    }
    if (i + count > size)
      count = size - i;
    var k;
    removed = new Array(count);
    for (k = 0;k < count; k++) {
      removed[k] = this._list[this._head + i + k & this._capacityMask];
    }
    i = this._head + i & this._capacityMask;
    if (index + count === size) {
      this._tail = this._tail - count + len & this._capacityMask;
      for (k = count;k > 0; k--) {
        this._list[i = i + 1 + len & this._capacityMask] = undefined;
      }
      return removed;
    }
    if (index === 0) {
      this._head = this._head + count + len & this._capacityMask;
      for (k = count - 1;k > 0; k--) {
        this._list[i = i + 1 + len & this._capacityMask] = undefined;
      }
      return removed;
    }
    if (i < size / 2) {
      this._head = this._head + index + count + len & this._capacityMask;
      for (k = index;k > 0; k--) {
        this.unshift(this._list[i = i - 1 + len & this._capacityMask]);
      }
      i = this._head - 1 + len & this._capacityMask;
      while (del_count > 0) {
        this._list[i = i - 1 + len & this._capacityMask] = undefined;
        del_count--;
      }
      if (index < 0)
        this._tail = i;
    } else {
      this._tail = i;
      i = i + count + len & this._capacityMask;
      for (k = size - (count + index);k > 0; k--) {
        this.push(this._list[i++]);
      }
      i = this._tail;
      while (del_count > 0) {
        this._list[i = i + 1 + len & this._capacityMask] = undefined;
        del_count--;
      }
    }
    if (this._head < 2 && this._tail > 1e4 && this._tail <= len >>> 2)
      this._shrinkArray();
    return removed;
  };
  Denque.prototype.splice = function splice(index, count) {
    var i = index;
    if (i !== (i | 0)) {
      return;
    }
    var size = this.size();
    if (i < 0)
      i += size;
    if (i > size)
      return;
    if (arguments.length > 2) {
      var k;
      var temp;
      var removed;
      var arg_len = arguments.length;
      var len = this._list.length;
      var arguments_index = 2;
      if (!size || i < size / 2) {
        temp = new Array(i);
        for (k = 0;k < i; k++) {
          temp[k] = this._list[this._head + k & this._capacityMask];
        }
        if (count === 0) {
          removed = [];
          if (i > 0) {
            this._head = this._head + i + len & this._capacityMask;
          }
        } else {
          removed = this.remove(i, count);
          this._head = this._head + i + len & this._capacityMask;
        }
        while (arg_len > arguments_index) {
          this.unshift(arguments[--arg_len]);
        }
        for (k = i;k > 0; k--) {
          this.unshift(temp[k - 1]);
        }
      } else {
        temp = new Array(size - (i + count));
        var leng = temp.length;
        for (k = 0;k < leng; k++) {
          temp[k] = this._list[this._head + i + count + k & this._capacityMask];
        }
        if (count === 0) {
          removed = [];
          if (i != size) {
            this._tail = this._head + i + len & this._capacityMask;
          }
        } else {
          removed = this.remove(i, count);
          this._tail = this._tail - leng + len & this._capacityMask;
        }
        while (arguments_index < arg_len) {
          this.push(arguments[arguments_index++]);
        }
        for (k = 0;k < leng; k++) {
          this.push(temp[k]);
        }
      }
      return removed;
    } else {
      return this.remove(i, count);
    }
  };
  Denque.prototype.clear = function clear() {
    this._list = new Array(this._list.length);
    this._head = 0;
    this._tail = 0;
  };
  Denque.prototype.isEmpty = function isEmpty() {
    return this._head === this._tail;
  };
  Denque.prototype.toArray = function toArray() {
    return this._copyArray(false);
  };
  Denque.prototype._fromArray = function _fromArray(array) {
    var length = array.length;
    var capacity = this._nextPowerOf2(length);
    this._list = new Array(capacity);
    this._capacityMask = capacity - 1;
    this._tail = length;
    for (var i = 0;i < length; i++)
      this._list[i] = array[i];
  };
  Denque.prototype._copyArray = function _copyArray(fullCopy, size) {
    var src = this._list;
    var capacity = src.length;
    var length = this.length;
    size = size | length;
    if (size == length && this._head < this._tail) {
      return this._list.slice(this._head, this._tail);
    }
    var dest = new Array(size);
    var k = 0;
    var i;
    if (fullCopy || this._head > this._tail) {
      for (i = this._head;i < capacity; i++)
        dest[k++] = src[i];
      for (i = 0;i < this._tail; i++)
        dest[k++] = src[i];
    } else {
      for (i = this._head;i < this._tail; i++)
        dest[k++] = src[i];
    }
    return dest;
  };
  Denque.prototype._growArray = function _growArray() {
    if (this._head != 0) {
      var newList = this._copyArray(true, this._list.length << 1);
      this._tail = this._list.length;
      this._head = 0;
      this._list = newList;
    } else {
      this._tail = this._list.length;
      this._list.length <<= 1;
    }
    this._capacityMask = this._capacityMask << 1 | 1;
  };
  Denque.prototype._shrinkArray = function _shrinkArray() {
    this._list.length >>>= 1;
    this._capacityMask >>>= 1;
  };
  Denque.prototype._nextPowerOf2 = function _nextPowerOf2(num) {
    var log2 = Math.log(num) / Math.log(2);
    var nextPow2 = 1 << log2 + 1;
    return Math.max(nextPow2, 4);
  };
  module.exports = Denque;
});

// node_modules/ioredis/built/cluster/DelayQueue.js
var require_DelayQueue = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var utils_1 = require_utils2();
  var Deque = require_denque();
  var debug = (0, utils_1.Debug)("delayqueue");

  class DelayQueue {
    constructor() {
      this.queues = {};
      this.timeouts = {};
    }
    push(bucket, item, options) {
      const callback = options.callback || process.nextTick;
      if (!this.queues[bucket]) {
        this.queues[bucket] = new Deque;
      }
      const queue = this.queues[bucket];
      queue.push(item);
      if (!this.timeouts[bucket]) {
        this.timeouts[bucket] = setTimeout(() => {
          callback(() => {
            this.timeouts[bucket] = null;
            this.execute(bucket);
          });
        }, options.timeout);
      }
    }
    execute(bucket) {
      const queue = this.queues[bucket];
      if (!queue) {
        return;
      }
      const { length } = queue;
      if (!length) {
        return;
      }
      debug("send %d commands in %s queue", length, bucket);
      this.queues[bucket] = null;
      while (queue.length > 0) {
        queue.shift()();
      }
    }
  }
  exports.default = DelayQueue;
});

// node_modules/ioredis/built/cluster/ShardedSubscriber.js
var require_ShardedSubscriber = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var util_1 = require_util();
  var utils_1 = require_utils2();
  var Redis_1 = require_Redis();
  var debug = (0, utils_1.Debug)("cluster:subscriberGroup:shardedSubscriber");

  class ShardedSubscriber {
    constructor(emitter, options) {
      this.emitter = emitter;
      this.started = false;
      this.instance = null;
      this.messageListeners = new Map;
      this.onEnd = () => {
        this.started = false;
        this.emitter.emit("-node", this.instance, this.nodeKey);
      };
      this.onError = (error) => {
        this.emitter.emit("nodeError", error, this.nodeKey);
      };
      this.onMoved = () => {
        this.emitter.emit("moved");
      };
      this.instance = new Redis_1.default({
        port: options.port,
        host: options.host,
        username: options.username,
        password: options.password,
        enableReadyCheck: false,
        offlineQueue: true,
        connectionName: (0, util_1.getConnectionName)("ssubscriber", options.connectionName),
        lazyConnect: true,
        tls: options.tls,
        retryStrategy: null
      });
      this.nodeKey = (0, util_1.getNodeKey)(options);
      this.instance.once("end", this.onEnd);
      this.instance.on("error", this.onError);
      this.instance.on("moved", this.onMoved);
      for (const event of ["smessage", "smessageBuffer"]) {
        const listener = (...args) => {
          this.emitter.emit(event, ...args);
        };
        this.messageListeners.set(event, listener);
        this.instance.on(event, listener);
      }
    }
    async start() {
      if (this.started) {
        debug("already started %s", this.nodeKey);
        return;
      }
      try {
        await this.instance.connect();
        debug("started %s", this.nodeKey);
        this.started = true;
      } catch (err) {
        debug("failed to start %s: %s", this.nodeKey, err);
        this.started = false;
        throw err;
      }
    }
    stop() {
      this.started = false;
      if (this.instance) {
        this.instance.disconnect();
        this.instance.removeAllListeners();
        this.messageListeners.clear();
        this.instance = null;
      }
      debug("stopped %s", this.nodeKey);
    }
    isStarted() {
      return this.started;
    }
    getInstance() {
      return this.instance;
    }
    getNodeKey() {
      return this.nodeKey;
    }
  }
  exports.default = ShardedSubscriber;
});

// node_modules/ioredis/built/cluster/ClusterSubscriberGroup.js
var require_ClusterSubscriberGroup = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var utils_1 = require_utils2();
  var util_1 = require_util();
  var calculateSlot = require_lib();
  var ShardedSubscriber_1 = require_ShardedSubscriber();
  var debug = (0, utils_1.Debug)("cluster:subscriberGroup");

  class ClusterSubscriberGroup {
    constructor(subscriberGroupEmitter) {
      this.subscriberGroupEmitter = subscriberGroupEmitter;
      this.shardedSubscribers = new Map;
      this.clusterSlots = [];
      this.subscriberToSlotsIndex = new Map;
      this.channels = new Map;
      this.failedAttemptsByNode = new Map;
      this.isResetting = false;
      this.pendingReset = null;
      this.handleSubscriberConnectFailed = (error, nodeKey) => {
        const currentAttempts = this.failedAttemptsByNode.get(nodeKey) || 0;
        const failedAttempts = currentAttempts + 1;
        this.failedAttemptsByNode.set(nodeKey, failedAttempts);
        const attempts = Math.min(failedAttempts, ClusterSubscriberGroup.MAX_RETRY_ATTEMPTS);
        const backoff = Math.min(ClusterSubscriberGroup.BASE_BACKOFF_MS * 2 ** attempts, ClusterSubscriberGroup.MAX_BACKOFF_MS);
        const jitter = Math.floor((Math.random() - 0.5) * (backoff * 0.5));
        const delay = Math.max(0, backoff + jitter);
        debug("Failed to connect subscriber for %s. Refreshing slots in %dms", nodeKey, delay);
        this.subscriberGroupEmitter.emit("subscriberConnectFailed", {
          delay,
          error
        });
      };
      this.handleSubscriberConnectSucceeded = (nodeKey) => {
        this.failedAttemptsByNode.delete(nodeKey);
      };
    }
    getResponsibleSubscriber(slot) {
      const nodeKey = this.clusterSlots[slot][0];
      return this.shardedSubscribers.get(nodeKey);
    }
    addChannels(channels) {
      const slot = calculateSlot(channels[0]);
      for (const c of channels) {
        if (calculateSlot(c) !== slot) {
          return -1;
        }
      }
      const currChannels = this.channels.get(slot);
      if (!currChannels) {
        this.channels.set(slot, channels);
      } else {
        this.channels.set(slot, currChannels.concat(channels));
      }
      return Array.from(this.channels.values()).reduce((sum, array) => sum + array.length, 0);
    }
    removeChannels(channels) {
      const slot = calculateSlot(channels[0]);
      for (const c of channels) {
        if (calculateSlot(c) !== slot) {
          return -1;
        }
      }
      const slotChannels = this.channels.get(slot);
      if (slotChannels) {
        const updatedChannels = slotChannels.filter((c) => !channels.includes(c));
        this.channels.set(slot, updatedChannels);
      }
      return Array.from(this.channels.values()).reduce((sum, array) => sum + array.length, 0);
    }
    stop() {
      for (const s of this.shardedSubscribers.values()) {
        s.stop();
      }
      this.pendingReset = null;
      this.shardedSubscribers.clear();
      this.subscriberToSlotsIndex.clear();
    }
    start() {
      const startPromises = [];
      for (const s of this.shardedSubscribers.values()) {
        if (!s.isStarted()) {
          startPromises.push(s.start().then(() => {
            this.handleSubscriberConnectSucceeded(s.getNodeKey());
          }).catch((err) => {
            this.handleSubscriberConnectFailed(err, s.getNodeKey());
          }));
        }
      }
      return Promise.all(startPromises);
    }
    async reset(clusterSlots, clusterNodes) {
      if (this.isResetting) {
        this.pendingReset = { slots: clusterSlots, nodes: clusterNodes };
        return;
      }
      this.isResetting = true;
      try {
        const hasTopologyChanged = this._refreshSlots(clusterSlots);
        const hasFailedSubscribers = this.hasUnhealthySubscribers();
        if (!hasTopologyChanged && !hasFailedSubscribers) {
          debug("No topology change detected or failed subscribers. Skipping reset.");
          return;
        }
        for (const [nodeKey, shardedSubscriber] of this.shardedSubscribers) {
          if (this.subscriberToSlotsIndex.has(nodeKey) && shardedSubscriber.isStarted()) {
            debug("Skipping deleting subscriber for %s", nodeKey);
            continue;
          }
          debug("Removing subscriber for %s", nodeKey);
          shardedSubscriber.stop();
          this.shardedSubscribers.delete(nodeKey);
          this.subscriberGroupEmitter.emit("-subscriber");
        }
        const startPromises = [];
        for (const [nodeKey, _] of this.subscriberToSlotsIndex) {
          if (this.shardedSubscribers.has(nodeKey)) {
            debug("Skipping creating new subscriber for %s", nodeKey);
            continue;
          }
          debug("Creating new subscriber for %s", nodeKey);
          const redis = clusterNodes.find((node) => {
            return (0, util_1.getNodeKey)(node.options) === nodeKey;
          });
          if (!redis) {
            debug("Failed to find node for key %s", nodeKey);
            continue;
          }
          const sub = new ShardedSubscriber_1.default(this.subscriberGroupEmitter, redis.options);
          this.shardedSubscribers.set(nodeKey, sub);
          startPromises.push(sub.start().then(() => {
            this.handleSubscriberConnectSucceeded(nodeKey);
          }).catch((error) => {
            this.handleSubscriberConnectFailed(error, nodeKey);
          }));
          this.subscriberGroupEmitter.emit("+subscriber");
        }
        await Promise.all(startPromises);
        this._resubscribe();
        this.subscriberGroupEmitter.emit("subscribersReady");
      } finally {
        this.isResetting = false;
        if (this.pendingReset) {
          const { slots, nodes } = this.pendingReset;
          this.pendingReset = null;
          await this.reset(slots, nodes);
        }
      }
    }
    _refreshSlots(targetSlots) {
      if (this._slotsAreEqual(targetSlots)) {
        debug("Nothing to refresh because the new cluster map is equal to the previous one.");
        return false;
      }
      debug("Refreshing the slots of the subscriber group.");
      this.subscriberToSlotsIndex = new Map;
      for (let slot = 0;slot < targetSlots.length; slot++) {
        const node = targetSlots[slot][0];
        if (!this.subscriberToSlotsIndex.has(node)) {
          this.subscriberToSlotsIndex.set(node, []);
        }
        this.subscriberToSlotsIndex.get(node).push(Number(slot));
      }
      this.clusterSlots = JSON.parse(JSON.stringify(targetSlots));
      return true;
    }
    _resubscribe() {
      if (this.shardedSubscribers) {
        this.shardedSubscribers.forEach((s, nodeKey) => {
          const subscriberSlots = this.subscriberToSlotsIndex.get(nodeKey);
          if (subscriberSlots) {
            subscriberSlots.forEach((ss) => {
              const redis = s.getInstance();
              const channels = this.channels.get(ss);
              if (channels && channels.length > 0) {
                if (redis.status === "end") {
                  return;
                }
                if (redis.status === "ready") {
                  redis.ssubscribe(...channels).catch((err) => {
                    debug("Failed to ssubscribe on node %s: %s", nodeKey, err);
                  });
                } else {
                  redis.once("ready", () => {
                    redis.ssubscribe(...channels).catch((err) => {
                      debug("Failed to ssubscribe on node %s: %s", nodeKey, err);
                    });
                  });
                }
              }
            });
          }
        });
      }
    }
    _slotsAreEqual(other) {
      if (this.clusterSlots === undefined) {
        return false;
      } else {
        return JSON.stringify(this.clusterSlots) === JSON.stringify(other);
      }
    }
    hasUnhealthySubscribers() {
      const hasFailedSubscribers = Array.from(this.shardedSubscribers.values()).some((sub) => !sub.isStarted());
      const hasMissingSubscribers = Array.from(this.subscriberToSlotsIndex.keys()).some((nodeKey) => !this.shardedSubscribers.has(nodeKey));
      return hasFailedSubscribers || hasMissingSubscribers;
    }
  }
  exports.default = ClusterSubscriberGroup;
  ClusterSubscriberGroup.MAX_RETRY_ATTEMPTS = 10;
  ClusterSubscriberGroup.MAX_BACKOFF_MS = 2000;
  ClusterSubscriberGroup.BASE_BACKOFF_MS = 100;
});

// node_modules/ioredis/built/cluster/index.js
var require_cluster = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var commands_1 = require_built();
  var events_1 = __require("events");
  var redis_errors_1 = require_redis_errors();
  var standard_as_callback_1 = require_built2();
  var Command_1 = require_Command();
  var ClusterAllFailedError_1 = require_ClusterAllFailedError();
  var Redis_1 = require_Redis();
  var ScanStream_1 = require_ScanStream();
  var transaction_1 = require_transaction();
  var utils_1 = require_utils2();
  var applyMixin_1 = require_applyMixin();
  var Commander_1 = require_Commander();
  var ClusterOptions_1 = require_ClusterOptions();
  var ClusterSubscriber_1 = require_ClusterSubscriber();
  var ConnectionPool_1 = require_ConnectionPool();
  var DelayQueue_1 = require_DelayQueue();
  var util_1 = require_util();
  var Deque = require_denque();
  var ClusterSubscriberGroup_1 = require_ClusterSubscriberGroup();
  var debug = (0, utils_1.Debug)("cluster");
  var REJECT_OVERWRITTEN_COMMANDS = new WeakSet;

  class Cluster extends Commander_1.default {
    constructor(startupNodes, options = {}) {
      super();
      this.slots = [];
      this._groupsIds = {};
      this._groupsBySlot = Array(16384);
      this.isCluster = true;
      this.retryAttempts = 0;
      this.delayQueue = new DelayQueue_1.default;
      this.offlineQueue = new Deque;
      this.isRefreshing = false;
      this._refreshSlotsCacheCallbacks = [];
      this._autoPipelines = new Map;
      this._runningAutoPipelines = new Set;
      this._readyDelayedCallbacks = [];
      this.connectionEpoch = 0;
      events_1.EventEmitter.call(this);
      this.startupNodes = startupNodes;
      this.options = (0, utils_1.defaults)({}, options, ClusterOptions_1.DEFAULT_CLUSTER_OPTIONS, this.options);
      if (this.options.shardedSubscribers) {
        this.createShardedSubscriberGroup();
      }
      if (this.options.redisOptions && this.options.redisOptions.keyPrefix && !this.options.keyPrefix) {
        this.options.keyPrefix = this.options.redisOptions.keyPrefix;
      }
      if (typeof this.options.scaleReads !== "function" && ["all", "master", "slave"].indexOf(this.options.scaleReads) === -1) {
        throw new Error('Invalid option scaleReads "' + this.options.scaleReads + '". Expected "all", "master", "slave" or a custom function');
      }
      this.connectionPool = new ConnectionPool_1.default(this.options.redisOptions);
      this.connectionPool.on("-node", (redis, key) => {
        this.emit("-node", redis);
      });
      this.connectionPool.on("+node", (redis) => {
        this.emit("+node", redis);
      });
      this.connectionPool.on("drain", () => {
        this.setStatus("close");
      });
      this.connectionPool.on("nodeError", (error, key) => {
        this.emit("node error", error, key);
      });
      this.subscriber = new ClusterSubscriber_1.default(this.connectionPool, this);
      if (this.options.scripts) {
        Object.entries(this.options.scripts).forEach(([name, definition]) => {
          this.defineCommand(name, definition);
        });
      }
      if (this.options.lazyConnect) {
        this.setStatus("wait");
      } else {
        this.connect().catch((err) => {
          debug("connecting failed: %s", err);
        });
      }
    }
    connect() {
      return new Promise((resolve, reject) => {
        if (this.status === "connecting" || this.status === "connect" || this.status === "ready") {
          reject(new Error("Redis is already connecting/connected"));
          return;
        }
        const epoch = ++this.connectionEpoch;
        this.setStatus("connecting");
        this.resolveStartupNodeHostnames().then((nodes) => {
          if (this.connectionEpoch !== epoch) {
            debug("discard connecting after resolving startup nodes because epoch not match: %d != %d", epoch, this.connectionEpoch);
            reject(new redis_errors_1.RedisError("Connection is discarded because a new connection is made"));
            return;
          }
          if (this.status !== "connecting") {
            debug("discard connecting after resolving startup nodes because the status changed to %s", this.status);
            reject(new redis_errors_1.RedisError("Connection is aborted"));
            return;
          }
          this.connectionPool.reset(nodes);
          if (this.options.shardedSubscribers) {
            this.shardedSubscribers.reset(this.slots, this.connectionPool.getNodes("all")).catch((err) => {
              debug("Error while starting subscribers: %s", err);
            });
          }
          const readyHandler = () => {
            this.setStatus("ready");
            this.retryAttempts = 0;
            this.executeOfflineCommands();
            this.resetNodesRefreshInterval();
            resolve();
          };
          let closeListener = undefined;
          const refreshListener = () => {
            this.invokeReadyDelayedCallbacks(undefined);
            this.removeListener("close", closeListener);
            this.manuallyClosing = false;
            this.setStatus("connect");
            if (this.options.enableReadyCheck) {
              this.readyCheck((err, fail) => {
                if (err || fail) {
                  debug("Ready check failed (%s). Reconnecting...", err || fail);
                  if (this.status === "connect") {
                    this.disconnect(true);
                  }
                } else {
                  readyHandler();
                }
              });
            } else {
              readyHandler();
            }
          };
          closeListener = () => {
            const error = new Error("None of startup nodes is available");
            this.removeListener("refresh", refreshListener);
            this.invokeReadyDelayedCallbacks(error);
            reject(error);
          };
          this.once("refresh", refreshListener);
          this.once("close", closeListener);
          this.once("close", this.handleCloseEvent.bind(this));
          this.refreshSlotsCache((err) => {
            if (err && err.message === ClusterAllFailedError_1.default.defaultMessage) {
              Redis_1.default.prototype.silentEmit.call(this, "error", err);
              this.connectionPool.reset([]);
            }
          });
          this.subscriber.start();
          if (this.options.shardedSubscribers) {
            this.shardedSubscribers.start().catch((err) => {
              debug("Error while starting subscribers: %s", err);
            });
          }
        }).catch((err) => {
          this.setStatus("close");
          this.handleCloseEvent(err);
          this.invokeReadyDelayedCallbacks(err);
          reject(err);
        });
      });
    }
    disconnect(reconnect = false) {
      const status = this.status;
      this.setStatus("disconnecting");
      if (!reconnect) {
        this.manuallyClosing = true;
      }
      if (this.reconnectTimeout && !reconnect) {
        clearTimeout(this.reconnectTimeout);
        this.reconnectTimeout = null;
        debug("Canceled reconnecting attempts");
      }
      this.clearNodesRefreshInterval();
      this.subscriber.stop();
      if (this.options.shardedSubscribers) {
        this.shardedSubscribers.stop();
      }
      if (status === "wait") {
        this.setStatus("close");
        this.handleCloseEvent();
      } else {
        this.connectionPool.reset([]);
      }
    }
    quit(callback) {
      const status = this.status;
      this.setStatus("disconnecting");
      this.manuallyClosing = true;
      if (this.reconnectTimeout) {
        clearTimeout(this.reconnectTimeout);
        this.reconnectTimeout = null;
      }
      this.clearNodesRefreshInterval();
      this.subscriber.stop();
      if (this.options.shardedSubscribers) {
        this.shardedSubscribers.stop();
      }
      if (status === "wait") {
        const ret = (0, standard_as_callback_1.default)(Promise.resolve("OK"), callback);
        setImmediate(function() {
          this.setStatus("close");
          this.handleCloseEvent();
        }.bind(this));
        return ret;
      }
      return (0, standard_as_callback_1.default)(Promise.all(this.nodes().map((node) => node.quit().catch((err) => {
        if (err.message === utils_1.CONNECTION_CLOSED_ERROR_MSG) {
          return "OK";
        }
        throw err;
      }))).then(() => "OK"), callback);
    }
    duplicate(overrideStartupNodes = [], overrideOptions = {}) {
      const startupNodes = overrideStartupNodes.length > 0 ? overrideStartupNodes : this.startupNodes.slice(0);
      const options = Object.assign({}, this.options, overrideOptions);
      return new Cluster(startupNodes, options);
    }
    nodes(role = "all") {
      if (role !== "all" && role !== "master" && role !== "slave") {
        throw new Error('Invalid role "' + role + '". Expected "all", "master" or "slave"');
      }
      return this.connectionPool.getNodes(role);
    }
    delayUntilReady(callback) {
      this._readyDelayedCallbacks.push(callback);
    }
    get autoPipelineQueueSize() {
      let queued = 0;
      for (const pipeline of this._autoPipelines.values()) {
        queued += pipeline.length;
      }
      return queued;
    }
    refreshSlotsCache(callback) {
      if (callback) {
        this._refreshSlotsCacheCallbacks.push(callback);
      }
      if (this.isRefreshing) {
        return;
      }
      this.isRefreshing = true;
      const _this = this;
      const wrapper = (error) => {
        this.isRefreshing = false;
        for (const callback2 of this._refreshSlotsCacheCallbacks) {
          callback2(error);
        }
        this._refreshSlotsCacheCallbacks = [];
      };
      const nodes = (0, utils_1.shuffle)(this.connectionPool.getNodes());
      let lastNodeError = null;
      function tryNode(index) {
        if (index === nodes.length) {
          const error = new ClusterAllFailedError_1.default(ClusterAllFailedError_1.default.defaultMessage, lastNodeError);
          return wrapper(error);
        }
        const node = nodes[index];
        const key = `${node.options.host}:${node.options.port}`;
        debug("getting slot cache from %s", key);
        _this.getInfoFromNode(node, function(err) {
          switch (_this.status) {
            case "close":
            case "end":
              return wrapper(new Error("Cluster is disconnected."));
            case "disconnecting":
              return wrapper(new Error("Cluster is disconnecting."));
          }
          if (err) {
            _this.emit("node error", err, key);
            lastNodeError = err;
            tryNode(index + 1);
          } else {
            _this.emit("refresh");
            wrapper();
          }
        });
      }
      tryNode(0);
    }
    sendCommand(command, stream, node) {
      if (this.status === "wait") {
        this.connect().catch(utils_1.noop);
      }
      if (this.status === "end") {
        command.reject(new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG));
        return command.promise;
      }
      let to = this.options.scaleReads;
      if (to !== "master") {
        const isCommandReadOnly = command.isReadOnly || (0, commands_1.exists)(command.name) && (0, commands_1.hasFlag)(command.name, "readonly");
        if (!isCommandReadOnly) {
          to = "master";
        }
      }
      let targetSlot = node ? node.slot : command.getSlot();
      const ttl = {};
      const _this = this;
      if (!node && !REJECT_OVERWRITTEN_COMMANDS.has(command)) {
        REJECT_OVERWRITTEN_COMMANDS.add(command);
        const reject = command.reject;
        command.reject = function(err) {
          const partialTry = tryConnection.bind(null, true);
          _this.handleError(err, ttl, {
            moved: function(slot, key) {
              debug("command %s is moved to %s", command.name, key);
              targetSlot = Number(slot);
              if (_this.slots[slot]) {
                _this.slots[slot][0] = key;
              } else {
                _this.slots[slot] = [key];
              }
              _this._groupsBySlot[slot] = _this._groupsIds[_this.slots[slot].join(";")];
              _this.connectionPool.findOrCreate(_this.natMapper(key));
              tryConnection();
              debug("refreshing slot caches... (triggered by MOVED error)");
              _this.refreshSlotsCache();
            },
            ask: function(slot, key) {
              debug("command %s is required to ask %s:%s", command.name, key);
              const mapped = _this.natMapper(key);
              _this.connectionPool.findOrCreate(mapped);
              tryConnection(false, `${mapped.host}:${mapped.port}`);
            },
            tryagain: partialTry,
            clusterDown: partialTry,
            connectionClosed: partialTry,
            maxRedirections: function(redirectionError) {
              reject.call(command, redirectionError);
            },
            defaults: function() {
              reject.call(command, err);
            }
          });
        };
      }
      tryConnection();
      function tryConnection(random, asking) {
        if (_this.status === "end") {
          command.reject(new redis_errors_1.AbortError("Cluster is ended."));
          return;
        }
        let redis;
        if (_this.status === "ready" || command.name === "cluster") {
          if (node && node.redis) {
            redis = node.redis;
          } else if (Command_1.default.checkFlag("ENTER_SUBSCRIBER_MODE", command.name) || Command_1.default.checkFlag("EXIT_SUBSCRIBER_MODE", command.name)) {
            if (_this.options.shardedSubscribers && (command.name == "ssubscribe" || command.name == "sunsubscribe")) {
              const sub = _this.shardedSubscribers.getResponsibleSubscriber(targetSlot);
              if (!sub) {
                command.reject(new redis_errors_1.AbortError(`No sharded subscriber for slot: ${targetSlot}`));
                return;
              }
              let status = -1;
              if (command.name == "ssubscribe") {
                status = _this.shardedSubscribers.addChannels(command.getKeys());
              }
              if (command.name == "sunsubscribe") {
                status = _this.shardedSubscribers.removeChannels(command.getKeys());
              }
              if (status !== -1) {
                redis = sub.getInstance();
              } else {
                command.reject(new redis_errors_1.AbortError("Possible CROSSSLOT error: All channels must hash to the same slot"));
              }
            } else {
              redis = _this.subscriber.getInstance();
            }
            if (!redis) {
              command.reject(new redis_errors_1.AbortError("No subscriber for the cluster"));
              return;
            }
          } else {
            if (!random) {
              if (typeof targetSlot === "number" && _this.slots[targetSlot]) {
                const nodeKeys = _this.slots[targetSlot];
                if (typeof to === "function") {
                  const nodes = nodeKeys.map(function(key) {
                    return _this.connectionPool.getInstanceByKey(key);
                  });
                  redis = to(nodes, command);
                  if (Array.isArray(redis)) {
                    redis = (0, utils_1.sample)(redis);
                  }
                  if (!redis) {
                    redis = nodes[0];
                  }
                } else {
                  let key;
                  if (to === "all") {
                    key = (0, utils_1.sample)(nodeKeys);
                  } else if (to === "slave" && nodeKeys.length > 1) {
                    key = (0, utils_1.sample)(nodeKeys, 1);
                  } else {
                    key = nodeKeys[0];
                  }
                  redis = _this.connectionPool.getInstanceByKey(key);
                }
              }
              if (asking) {
                redis = _this.connectionPool.getInstanceByKey(asking);
                redis.asking();
              }
            }
            if (!redis) {
              redis = (typeof to === "function" ? null : _this.connectionPool.getSampleInstance(to)) || _this.connectionPool.getSampleInstance("all");
            }
          }
          if (node && !node.redis) {
            node.redis = redis;
          }
        }
        if (redis) {
          redis.sendCommand(command, stream);
        } else if (_this.options.enableOfflineQueue) {
          _this.offlineQueue.push({
            command,
            stream,
            node
          });
        } else {
          command.reject(new Error("Cluster isn't ready and enableOfflineQueue options is false"));
        }
      }
      return command.promise;
    }
    sscanStream(key, options) {
      return this.createScanStream("sscan", { key, options });
    }
    sscanBufferStream(key, options) {
      return this.createScanStream("sscanBuffer", { key, options });
    }
    hscanStream(key, options) {
      return this.createScanStream("hscan", { key, options });
    }
    hscanBufferStream(key, options) {
      return this.createScanStream("hscanBuffer", { key, options });
    }
    zscanStream(key, options) {
      return this.createScanStream("zscan", { key, options });
    }
    zscanBufferStream(key, options) {
      return this.createScanStream("zscanBuffer", { key, options });
    }
    handleError(error, ttl, handlers) {
      if (typeof ttl.value === "undefined") {
        ttl.value = this.options.maxRedirections;
      } else {
        ttl.value -= 1;
      }
      if (ttl.value <= 0) {
        handlers.maxRedirections(new Error("Too many Cluster redirections. Last error: " + error));
        return;
      }
      const errv = error.message.split(" ");
      if (errv[0] === "MOVED") {
        const timeout = this.options.retryDelayOnMoved;
        if (timeout && typeof timeout === "number") {
          this.delayQueue.push("moved", handlers.moved.bind(null, errv[1], errv[2]), { timeout });
        } else {
          handlers.moved(errv[1], errv[2]);
        }
      } else if (errv[0] === "ASK") {
        handlers.ask(errv[1], errv[2]);
      } else if (errv[0] === "TRYAGAIN") {
        this.delayQueue.push("tryagain", handlers.tryagain, {
          timeout: this.options.retryDelayOnTryAgain
        });
      } else if (errv[0] === "CLUSTERDOWN" && this.options.retryDelayOnClusterDown > 0) {
        this.delayQueue.push("clusterdown", handlers.connectionClosed, {
          timeout: this.options.retryDelayOnClusterDown,
          callback: this.refreshSlotsCache.bind(this)
        });
      } else if (error.message === utils_1.CONNECTION_CLOSED_ERROR_MSG && this.options.retryDelayOnFailover > 0 && this.status === "ready") {
        this.delayQueue.push("failover", handlers.connectionClosed, {
          timeout: this.options.retryDelayOnFailover,
          callback: this.refreshSlotsCache.bind(this)
        });
      } else {
        handlers.defaults();
      }
    }
    resetOfflineQueue() {
      this.offlineQueue = new Deque;
    }
    clearNodesRefreshInterval() {
      if (this.slotsTimer) {
        clearTimeout(this.slotsTimer);
        this.slotsTimer = null;
      }
    }
    resetNodesRefreshInterval() {
      if (this.slotsTimer || !this.options.slotsRefreshInterval) {
        return;
      }
      const nextRound = () => {
        this.slotsTimer = setTimeout(() => {
          debug('refreshing slot caches... (triggered by "slotsRefreshInterval" option)');
          this.refreshSlotsCache(() => {
            nextRound();
          });
        }, this.options.slotsRefreshInterval);
      };
      nextRound();
    }
    setStatus(status) {
      debug("status: %s -> %s", this.status || "[empty]", status);
      this.status = status;
      process.nextTick(() => {
        this.emit(status);
      });
    }
    handleCloseEvent(reason) {
      var _a;
      if (reason) {
        debug("closed because %s", reason);
      }
      let retryDelay;
      if (!this.manuallyClosing && typeof this.options.clusterRetryStrategy === "function") {
        retryDelay = this.options.clusterRetryStrategy.call(this, ++this.retryAttempts, reason);
      }
      if (typeof retryDelay === "number") {
        this.setStatus("reconnecting");
        this.reconnectTimeout = setTimeout(() => {
          this.reconnectTimeout = null;
          debug("Cluster is disconnected. Retrying after %dms", retryDelay);
          this.connect().catch(function(err) {
            debug("Got error %s when reconnecting. Ignoring...", err);
          });
        }, retryDelay);
      } else {
        if (this.options.shardedSubscribers) {
          (_a = this.subscriberGroupEmitter) === null || _a === undefined || _a.removeAllListeners();
        }
        this.setStatus("end");
        this.flushQueue(new Error("None of startup nodes is available"));
      }
    }
    flushQueue(error) {
      let item;
      while (item = this.offlineQueue.shift()) {
        item.command.reject(error);
      }
    }
    executeOfflineCommands() {
      if (this.offlineQueue.length) {
        debug("send %d commands in offline queue", this.offlineQueue.length);
        const offlineQueue = this.offlineQueue;
        this.resetOfflineQueue();
        let item;
        while (item = offlineQueue.shift()) {
          this.sendCommand(item.command, item.stream, item.node);
        }
      }
    }
    natMapper(nodeKey) {
      const key = typeof nodeKey === "string" ? nodeKey : `${nodeKey.host}:${nodeKey.port}`;
      let mapped = null;
      if (this.options.natMap && typeof this.options.natMap === "function") {
        mapped = this.options.natMap(key);
      } else if (this.options.natMap && typeof this.options.natMap === "object") {
        mapped = this.options.natMap[key];
      }
      if (mapped) {
        debug("NAT mapping %s -> %O", key, mapped);
        return Object.assign({}, mapped);
      }
      return typeof nodeKey === "string" ? (0, util_1.nodeKeyToRedisOptions)(nodeKey) : nodeKey;
    }
    getInfoFromNode(redis, callback) {
      if (!redis) {
        return callback(new Error("Node is disconnected"));
      }
      const duplicatedConnection = redis.duplicate({
        enableOfflineQueue: true,
        enableReadyCheck: false,
        retryStrategy: null,
        connectionName: (0, util_1.getConnectionName)("refresher", this.options.redisOptions && this.options.redisOptions.connectionName)
      });
      duplicatedConnection.on("error", utils_1.noop);
      duplicatedConnection.cluster("SLOTS", (0, utils_1.timeout)((err, result) => {
        duplicatedConnection.disconnect();
        if (err) {
          debug("error encountered running CLUSTER.SLOTS: %s", err);
          return callback(err);
        }
        if (this.status === "disconnecting" || this.status === "close" || this.status === "end") {
          debug("ignore CLUSTER.SLOTS results (count: %d) since cluster status is %s", result.length, this.status);
          callback();
          return;
        }
        const nodes = [];
        debug("cluster slots result count: %d", result.length);
        for (let i = 0;i < result.length; ++i) {
          const items = result[i];
          const slotRangeStart = items[0];
          const slotRangeEnd = items[1];
          const keys = [];
          for (let j2 = 2;j2 < items.length; j2++) {
            if (!items[j2][0]) {
              continue;
            }
            const node = this.natMapper({
              host: items[j2][0],
              port: items[j2][1]
            });
            node.readOnly = j2 !== 2;
            nodes.push(node);
            keys.push(node.host + ":" + node.port);
          }
          debug("cluster slots result [%d]: slots %d~%d served by %s", i, slotRangeStart, slotRangeEnd, keys);
          for (let slot = slotRangeStart;slot <= slotRangeEnd; slot++) {
            this.slots[slot] = keys;
          }
        }
        this._groupsIds = Object.create(null);
        let j = 0;
        for (let i = 0;i < 16384; i++) {
          const target = (this.slots[i] || []).join(";");
          if (!target.length) {
            this._groupsBySlot[i] = undefined;
            continue;
          }
          if (!this._groupsIds[target]) {
            this._groupsIds[target] = ++j;
          }
          this._groupsBySlot[i] = this._groupsIds[target];
        }
        this.connectionPool.reset(nodes);
        if (this.options.shardedSubscribers) {
          this.shardedSubscribers.reset(this.slots, this.connectionPool.getNodes("all")).catch((err2) => {
            debug("Error while starting subscribers: %s", err2);
          });
        }
        callback();
      }, this.options.slotsRefreshTimeout));
    }
    invokeReadyDelayedCallbacks(err) {
      for (const c of this._readyDelayedCallbacks) {
        process.nextTick(c, err);
      }
      this._readyDelayedCallbacks = [];
    }
    readyCheck(callback) {
      this.cluster("INFO", (err, res) => {
        if (err) {
          return callback(err);
        }
        if (typeof res !== "string") {
          return callback();
        }
        let state;
        const lines = res.split(`\r
`);
        for (let i = 0;i < lines.length; ++i) {
          const parts = lines[i].split(":");
          if (parts[0] === "cluster_state") {
            state = parts[1];
            break;
          }
        }
        if (state === "fail") {
          debug("cluster state not ok (%s)", state);
          callback(null, state);
        } else {
          callback();
        }
      });
    }
    resolveSrv(hostname) {
      return new Promise((resolve, reject) => {
        this.options.resolveSrv(hostname, (err, records) => {
          if (err) {
            return reject(err);
          }
          const self = this, groupedRecords = (0, util_1.groupSrvRecords)(records), sortedKeys = Object.keys(groupedRecords).sort((a, b) => parseInt(a) - parseInt(b));
          function tryFirstOne(err2) {
            if (!sortedKeys.length) {
              return reject(err2);
            }
            const key = sortedKeys[0], group = groupedRecords[key], record = (0, util_1.weightSrvRecords)(group);
            if (!group.records.length) {
              sortedKeys.shift();
            }
            self.dnsLookup(record.name).then((host) => resolve({
              host,
              port: record.port
            }), tryFirstOne);
          }
          tryFirstOne();
        });
      });
    }
    dnsLookup(hostname) {
      return new Promise((resolve, reject) => {
        this.options.dnsLookup(hostname, (err, address) => {
          if (err) {
            debug("failed to resolve hostname %s to IP: %s", hostname, err.message);
            reject(err);
          } else {
            debug("resolved hostname %s to IP %s", hostname, address);
            resolve(address);
          }
        });
      });
    }
    async resolveStartupNodeHostnames() {
      if (!Array.isArray(this.startupNodes) || this.startupNodes.length === 0) {
        throw new Error("`startupNodes` should contain at least one node.");
      }
      const startupNodes = (0, util_1.normalizeNodeOptions)(this.startupNodes);
      const hostnames = (0, util_1.getUniqueHostnamesFromOptions)(startupNodes);
      if (hostnames.length === 0) {
        return startupNodes;
      }
      const configs = await Promise.all(hostnames.map((this.options.useSRVRecords ? this.resolveSrv : this.dnsLookup).bind(this)));
      const hostnameToConfig = (0, utils_1.zipMap)(hostnames, configs);
      return startupNodes.map((node) => {
        const config = hostnameToConfig.get(node.host);
        if (!config) {
          return node;
        }
        if (this.options.useSRVRecords) {
          return Object.assign({}, node, config);
        }
        return Object.assign({}, node, { host: config });
      });
    }
    createScanStream(command, { key, options = {} }) {
      return new ScanStream_1.default({
        objectMode: true,
        key,
        redis: this,
        command,
        ...options
      });
    }
    createShardedSubscriberGroup() {
      this.subscriberGroupEmitter = new events_1.EventEmitter;
      this.shardedSubscribers = new ClusterSubscriberGroup_1.default(this.subscriberGroupEmitter);
      const refreshSlotsCacheCallback = (err) => {
        if (err instanceof ClusterAllFailedError_1.default) {
          this.disconnect(true);
        }
      };
      this.subscriberGroupEmitter.on("-node", (redis, nodeKey) => {
        this.emit("-node", redis, nodeKey);
        this.refreshSlotsCache(refreshSlotsCacheCallback);
      });
      this.subscriberGroupEmitter.on("subscriberConnectFailed", ({ delay, error }) => {
        this.emit("error", error);
        setTimeout(() => {
          this.refreshSlotsCache(refreshSlotsCacheCallback);
        }, delay);
      });
      this.subscriberGroupEmitter.on("moved", () => {
        this.refreshSlotsCache(refreshSlotsCacheCallback);
      });
      this.subscriberGroupEmitter.on("-subscriber", () => {
        this.emit("-subscriber");
      });
      this.subscriberGroupEmitter.on("+subscriber", () => {
        this.emit("+subscriber");
      });
      this.subscriberGroupEmitter.on("nodeError", (error, nodeKey) => {
        this.emit("nodeError", error, nodeKey);
      });
      this.subscriberGroupEmitter.on("subscribersReady", () => {
        this.emit("subscribersReady");
      });
      for (const event of ["smessage", "smessageBuffer"]) {
        this.subscriberGroupEmitter.on(event, (arg1, arg2, arg3) => {
          this.emit(event, arg1, arg2, arg3);
        });
      }
    }
  }
  (0, applyMixin_1.default)(Cluster, events_1.EventEmitter);
  (0, transaction_1.addTransactionSupport)(Cluster.prototype);
  exports.default = Cluster;
});

// node_modules/ioredis/built/connectors/AbstractConnector.js
var require_AbstractConnector = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var utils_1 = require_utils2();
  var debug = (0, utils_1.Debug)("AbstractConnector");

  class AbstractConnector {
    constructor(disconnectTimeout) {
      this.connecting = false;
      this.disconnectTimeout = disconnectTimeout;
    }
    check(info) {
      return true;
    }
    disconnect() {
      this.connecting = false;
      if (this.stream) {
        const stream = this.stream;
        const timeout = setTimeout(() => {
          debug("stream %s:%s still open, destroying it", stream.remoteAddress, stream.remotePort);
          stream.destroy();
        }, this.disconnectTimeout);
        stream.on("close", () => clearTimeout(timeout));
        stream.end();
      }
    }
  }
  exports.default = AbstractConnector;
});

// node_modules/ioredis/built/connectors/StandaloneConnector.js
var require_StandaloneConnector = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var net_1 = __require("net");
  var tls_1 = __require("tls");
  var utils_1 = require_utils2();
  var AbstractConnector_1 = require_AbstractConnector();

  class StandaloneConnector extends AbstractConnector_1.default {
    constructor(options) {
      super(options.disconnectTimeout);
      this.options = options;
    }
    connect(_) {
      const { options } = this;
      this.connecting = true;
      let connectionOptions;
      if ("path" in options && options.path) {
        connectionOptions = {
          path: options.path
        };
      } else {
        connectionOptions = {};
        if ("port" in options && options.port != null) {
          connectionOptions.port = options.port;
        }
        if ("host" in options && options.host != null) {
          connectionOptions.host = options.host;
        }
        if ("family" in options && options.family != null) {
          connectionOptions.family = options.family;
        }
      }
      if (options.tls) {
        Object.assign(connectionOptions, options.tls);
      }
      return new Promise((resolve, reject) => {
        process.nextTick(() => {
          if (!this.connecting) {
            reject(new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG));
            return;
          }
          try {
            if (options.tls) {
              this.stream = (0, tls_1.connect)(connectionOptions);
            } else {
              this.stream = (0, net_1.createConnection)(connectionOptions);
            }
          } catch (err) {
            reject(err);
            return;
          }
          this.stream.once("error", (err) => {
            this.firstError = err;
          });
          resolve(this.stream);
        });
      });
    }
  }
  exports.default = StandaloneConnector;
});

// node_modules/ioredis/built/connectors/SentinelConnector/SentinelIterator.js
var require_SentinelIterator = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  function isSentinelEql(a, b) {
    return (a.host || "127.0.0.1") === (b.host || "127.0.0.1") && (a.port || 26379) === (b.port || 26379);
  }

  class SentinelIterator {
    constructor(sentinels) {
      this.cursor = 0;
      this.sentinels = sentinels.slice(0);
    }
    next() {
      const done = this.cursor >= this.sentinels.length;
      return { done, value: done ? undefined : this.sentinels[this.cursor++] };
    }
    reset(moveCurrentEndpointToFirst) {
      if (moveCurrentEndpointToFirst && this.sentinels.length > 1 && this.cursor !== 1) {
        this.sentinels.unshift(...this.sentinels.splice(this.cursor - 1));
      }
      this.cursor = 0;
    }
    add(sentinel) {
      for (let i = 0;i < this.sentinels.length; i++) {
        if (isSentinelEql(sentinel, this.sentinels[i])) {
          return false;
        }
      }
      this.sentinels.push(sentinel);
      return true;
    }
    toString() {
      return `${JSON.stringify(this.sentinels)} @${this.cursor}`;
    }
  }
  exports.default = SentinelIterator;
});

// node_modules/ioredis/built/connectors/SentinelConnector/FailoverDetector.js
var require_FailoverDetector = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.FailoverDetector = undefined;
  var utils_1 = require_utils2();
  var debug = (0, utils_1.Debug)("FailoverDetector");
  var CHANNEL_NAME = "+switch-master";

  class FailoverDetector {
    constructor(connector, sentinels) {
      this.isDisconnected = false;
      this.connector = connector;
      this.sentinels = sentinels;
    }
    cleanup() {
      this.isDisconnected = true;
      for (const sentinel of this.sentinels) {
        sentinel.client.disconnect();
      }
    }
    async subscribe() {
      debug("Starting FailoverDetector");
      const promises = [];
      for (const sentinel of this.sentinels) {
        const promise = sentinel.client.subscribe(CHANNEL_NAME).catch((err) => {
          debug("Failed to subscribe to failover messages on sentinel %s:%s (%s)", sentinel.address.host || "127.0.0.1", sentinel.address.port || 26739, err.message);
        });
        promises.push(promise);
        sentinel.client.on("message", (channel) => {
          if (!this.isDisconnected && channel === CHANNEL_NAME) {
            this.disconnect();
          }
        });
      }
      await Promise.all(promises);
    }
    disconnect() {
      this.isDisconnected = true;
      debug("Failover detected, disconnecting");
      this.connector.disconnect();
    }
  }
  exports.FailoverDetector = FailoverDetector;
});

// node_modules/ioredis/built/connectors/SentinelConnector/index.js
var require_SentinelConnector = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.SentinelIterator = undefined;
  var net_1 = __require("net");
  var utils_1 = require_utils2();
  var tls_1 = __require("tls");
  var SentinelIterator_1 = require_SentinelIterator();
  exports.SentinelIterator = SentinelIterator_1.default;
  var AbstractConnector_1 = require_AbstractConnector();
  var Redis_1 = require_Redis();
  var FailoverDetector_1 = require_FailoverDetector();
  var debug = (0, utils_1.Debug)("SentinelConnector");

  class SentinelConnector extends AbstractConnector_1.default {
    constructor(options) {
      super(options.disconnectTimeout);
      this.options = options;
      this.emitter = null;
      this.failoverDetector = null;
      if (!this.options.sentinels.length) {
        throw new Error("Requires at least one sentinel to connect to.");
      }
      if (!this.options.name) {
        throw new Error("Requires the name of master.");
      }
      this.sentinelIterator = new SentinelIterator_1.default(this.options.sentinels);
    }
    check(info) {
      const roleMatches = !info.role || this.options.role === info.role;
      if (!roleMatches) {
        debug("role invalid, expected %s, but got %s", this.options.role, info.role);
        this.sentinelIterator.next();
        this.sentinelIterator.next();
        this.sentinelIterator.reset(true);
      }
      return roleMatches;
    }
    disconnect() {
      super.disconnect();
      if (this.failoverDetector) {
        this.failoverDetector.cleanup();
      }
    }
    connect(eventEmitter) {
      this.connecting = true;
      this.retryAttempts = 0;
      let lastError;
      const connectToNext = async () => {
        const endpoint = this.sentinelIterator.next();
        if (endpoint.done) {
          this.sentinelIterator.reset(false);
          const retryDelay = typeof this.options.sentinelRetryStrategy === "function" ? this.options.sentinelRetryStrategy(++this.retryAttempts) : null;
          let errorMsg = typeof retryDelay !== "number" ? "All sentinels are unreachable and retry is disabled." : `All sentinels are unreachable. Retrying from scratch after ${retryDelay}ms.`;
          if (lastError) {
            errorMsg += ` Last error: ${lastError.message}`;
          }
          debug(errorMsg);
          const error = new Error(errorMsg);
          if (typeof retryDelay === "number") {
            eventEmitter("error", error);
            await new Promise((resolve) => setTimeout(resolve, retryDelay));
            return connectToNext();
          } else {
            throw error;
          }
        }
        let resolved = null;
        let err = null;
        try {
          resolved = await this.resolve(endpoint.value);
        } catch (error) {
          err = error;
        }
        if (!this.connecting) {
          throw new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG);
        }
        const endpointAddress = endpoint.value.host + ":" + endpoint.value.port;
        if (resolved) {
          debug("resolved: %s:%s from sentinel %s", resolved.host, resolved.port, endpointAddress);
          if (this.options.enableTLSForSentinelMode && this.options.tls) {
            Object.assign(resolved, this.options.tls);
            this.stream = (0, tls_1.connect)(resolved);
            this.stream.once("secureConnect", this.initFailoverDetector.bind(this));
          } else {
            this.stream = (0, net_1.createConnection)(resolved);
            this.stream.once("connect", this.initFailoverDetector.bind(this));
          }
          this.stream.once("error", (err2) => {
            this.firstError = err2;
          });
          return this.stream;
        } else {
          const errorMsg = err ? "failed to connect to sentinel " + endpointAddress + " because " + err.message : "connected to sentinel " + endpointAddress + " successfully, but got an invalid reply: " + resolved;
          debug(errorMsg);
          eventEmitter("sentinelError", new Error(errorMsg));
          if (err) {
            lastError = err;
          }
          return connectToNext();
        }
      };
      return connectToNext();
    }
    async updateSentinels(client) {
      if (!this.options.updateSentinels) {
        return;
      }
      const result = await client.sentinel("sentinels", this.options.name);
      if (!Array.isArray(result)) {
        return;
      }
      result.map(utils_1.packObject).forEach((sentinel) => {
        const flags = sentinel.flags ? sentinel.flags.split(",") : [];
        if (flags.indexOf("disconnected") === -1 && sentinel.ip && sentinel.port) {
          const endpoint = this.sentinelNatResolve(addressResponseToAddress(sentinel));
          if (this.sentinelIterator.add(endpoint)) {
            debug("adding sentinel %s:%s", endpoint.host, endpoint.port);
          }
        }
      });
      debug("Updated internal sentinels: %s", this.sentinelIterator);
    }
    async resolveMaster(client) {
      const result = await client.sentinel("get-master-addr-by-name", this.options.name);
      await this.updateSentinels(client);
      return this.sentinelNatResolve(Array.isArray(result) ? { host: result[0], port: Number(result[1]) } : null);
    }
    async resolveSlave(client) {
      const result = await client.sentinel("slaves", this.options.name);
      if (!Array.isArray(result)) {
        return null;
      }
      const availableSlaves = result.map(utils_1.packObject).filter((slave) => slave.flags && !slave.flags.match(/(disconnected|s_down|o_down)/));
      return this.sentinelNatResolve(selectPreferredSentinel(availableSlaves, this.options.preferredSlaves));
    }
    sentinelNatResolve(item) {
      if (!item || !this.options.natMap)
        return item;
      const key = `${item.host}:${item.port}`;
      let result = item;
      if (typeof this.options.natMap === "function") {
        result = this.options.natMap(key) || item;
      } else if (typeof this.options.natMap === "object") {
        result = this.options.natMap[key] || item;
      }
      return result;
    }
    connectToSentinel(endpoint, options) {
      const redis = new Redis_1.default({
        port: endpoint.port || 26379,
        host: endpoint.host,
        username: this.options.sentinelUsername || null,
        password: this.options.sentinelPassword || null,
        family: endpoint.family || ("path" in this.options && this.options.path ? undefined : this.options.family),
        tls: this.options.sentinelTLS,
        retryStrategy: null,
        enableReadyCheck: false,
        connectTimeout: this.options.connectTimeout,
        commandTimeout: this.options.sentinelCommandTimeout,
        ...options
      });
      return redis;
    }
    async resolve(endpoint) {
      const client = this.connectToSentinel(endpoint);
      client.on("error", noop);
      try {
        if (this.options.role === "slave") {
          return await this.resolveSlave(client);
        } else {
          return await this.resolveMaster(client);
        }
      } finally {
        client.disconnect();
      }
    }
    async initFailoverDetector() {
      var _a;
      if (!this.options.failoverDetector) {
        return;
      }
      this.sentinelIterator.reset(true);
      const sentinels = [];
      while (sentinels.length < this.options.sentinelMaxConnections) {
        const { done, value } = this.sentinelIterator.next();
        if (done) {
          break;
        }
        const client = this.connectToSentinel(value, {
          lazyConnect: true,
          retryStrategy: this.options.sentinelReconnectStrategy
        });
        client.on("reconnecting", () => {
          var _a2;
          (_a2 = this.emitter) === null || _a2 === undefined || _a2.emit("sentinelReconnecting");
        });
        sentinels.push({ address: value, client });
      }
      this.sentinelIterator.reset(false);
      if (this.failoverDetector) {
        this.failoverDetector.cleanup();
      }
      this.failoverDetector = new FailoverDetector_1.FailoverDetector(this, sentinels);
      await this.failoverDetector.subscribe();
      (_a = this.emitter) === null || _a === undefined || _a.emit("failoverSubscribed");
    }
  }
  exports.default = SentinelConnector;
  function selectPreferredSentinel(availableSlaves, preferredSlaves) {
    if (availableSlaves.length === 0) {
      return null;
    }
    let selectedSlave;
    if (typeof preferredSlaves === "function") {
      selectedSlave = preferredSlaves(availableSlaves);
    } else if (preferredSlaves !== null && typeof preferredSlaves === "object") {
      const preferredSlavesArray = Array.isArray(preferredSlaves) ? preferredSlaves : [preferredSlaves];
      preferredSlavesArray.sort((a, b) => {
        if (!a.prio) {
          a.prio = 1;
        }
        if (!b.prio) {
          b.prio = 1;
        }
        if (a.prio < b.prio) {
          return -1;
        }
        if (a.prio > b.prio) {
          return 1;
        }
        return 0;
      });
      for (let p = 0;p < preferredSlavesArray.length; p++) {
        for (let a = 0;a < availableSlaves.length; a++) {
          const slave = availableSlaves[a];
          if (slave.ip === preferredSlavesArray[p].ip) {
            if (slave.port === preferredSlavesArray[p].port) {
              selectedSlave = slave;
              break;
            }
          }
        }
        if (selectedSlave) {
          break;
        }
      }
    }
    if (!selectedSlave) {
      selectedSlave = (0, utils_1.sample)(availableSlaves);
    }
    return addressResponseToAddress(selectedSlave);
  }
  function addressResponseToAddress(input) {
    return { host: input.ip, port: Number(input.port) };
  }
  function noop() {}
});

// node_modules/ioredis/built/connectors/index.js
var require_connectors = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.SentinelConnector = exports.StandaloneConnector = undefined;
  var StandaloneConnector_1 = require_StandaloneConnector();
  exports.StandaloneConnector = StandaloneConnector_1.default;
  var SentinelConnector_1 = require_SentinelConnector();
  exports.SentinelConnector = SentinelConnector_1.default;
});

// node_modules/ioredis/built/errors/MaxRetriesPerRequestError.js
var require_MaxRetriesPerRequestError = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var redis_errors_1 = require_redis_errors();

  class MaxRetriesPerRequestError extends redis_errors_1.AbortError {
    constructor(maxRetriesPerRequest) {
      const message = `Reached the max retries per request limit (which is ${maxRetriesPerRequest}). Refer to "maxRetriesPerRequest" option for details.`;
      super(message);
      Error.captureStackTrace(this, this.constructor);
    }
    get name() {
      return this.constructor.name;
    }
  }
  exports.default = MaxRetriesPerRequestError;
});

// node_modules/ioredis/built/errors/index.js
var require_errors = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.MaxRetriesPerRequestError = undefined;
  var MaxRetriesPerRequestError_1 = require_MaxRetriesPerRequestError();
  exports.MaxRetriesPerRequestError = MaxRetriesPerRequestError_1.default;
});

// node_modules/redis-parser/lib/parser.js
var require_parser = __commonJS((exports, module) => {
  var Buffer2 = __require("buffer").Buffer;
  var StringDecoder = __require("string_decoder").StringDecoder;
  var decoder = new StringDecoder;
  var errors = require_redis_errors();
  var ReplyError = errors.ReplyError;
  var ParserError = errors.ParserError;
  var bufferPool = Buffer2.allocUnsafe(32 * 1024);
  var bufferOffset = 0;
  var interval = null;
  var counter = 0;
  var notDecreased = 0;
  function parseSimpleNumbers(parser) {
    const length = parser.buffer.length - 1;
    var offset = parser.offset;
    var number = 0;
    var sign = 1;
    if (parser.buffer[offset] === 45) {
      sign = -1;
      offset++;
    }
    while (offset < length) {
      const c1 = parser.buffer[offset++];
      if (c1 === 13) {
        parser.offset = offset + 1;
        return sign * number;
      }
      number = number * 10 + (c1 - 48);
    }
  }
  function parseStringNumbers(parser) {
    const length = parser.buffer.length - 1;
    var offset = parser.offset;
    var number = 0;
    var res = "";
    if (parser.buffer[offset] === 45) {
      res += "-";
      offset++;
    }
    while (offset < length) {
      var c1 = parser.buffer[offset++];
      if (c1 === 13) {
        parser.offset = offset + 1;
        if (number !== 0) {
          res += number;
        }
        return res;
      } else if (number > 429496728) {
        res += number * 10 + (c1 - 48);
        number = 0;
      } else if (c1 === 48 && number === 0) {
        res += 0;
      } else {
        number = number * 10 + (c1 - 48);
      }
    }
  }
  function parseSimpleString(parser) {
    const start = parser.offset;
    const buffer = parser.buffer;
    const length = buffer.length - 1;
    var offset = start;
    while (offset < length) {
      if (buffer[offset++] === 13) {
        parser.offset = offset + 1;
        if (parser.optionReturnBuffers === true) {
          return parser.buffer.slice(start, offset - 1);
        }
        return parser.buffer.toString("utf8", start, offset - 1);
      }
    }
  }
  function parseLength(parser) {
    const length = parser.buffer.length - 1;
    var offset = parser.offset;
    var number = 0;
    while (offset < length) {
      const c1 = parser.buffer[offset++];
      if (c1 === 13) {
        parser.offset = offset + 1;
        return number;
      }
      number = number * 10 + (c1 - 48);
    }
  }
  function parseInteger(parser) {
    if (parser.optionStringNumbers === true) {
      return parseStringNumbers(parser);
    }
    return parseSimpleNumbers(parser);
  }
  function parseBulkString(parser) {
    const length = parseLength(parser);
    if (length === undefined) {
      return;
    }
    if (length < 0) {
      return null;
    }
    const offset = parser.offset + length;
    if (offset + 2 > parser.buffer.length) {
      parser.bigStrSize = offset + 2;
      parser.totalChunkSize = parser.buffer.length;
      parser.bufferCache.push(parser.buffer);
      return;
    }
    const start = parser.offset;
    parser.offset = offset + 2;
    if (parser.optionReturnBuffers === true) {
      return parser.buffer.slice(start, offset);
    }
    return parser.buffer.toString("utf8", start, offset);
  }
  function parseError(parser) {
    var string = parseSimpleString(parser);
    if (string !== undefined) {
      if (parser.optionReturnBuffers === true) {
        string = string.toString();
      }
      return new ReplyError(string);
    }
  }
  function handleError(parser, type) {
    const err = new ParserError("Protocol error, got " + JSON.stringify(String.fromCharCode(type)) + " as reply type byte", JSON.stringify(parser.buffer), parser.offset);
    parser.buffer = null;
    parser.returnFatalError(err);
  }
  function parseArray(parser) {
    const length = parseLength(parser);
    if (length === undefined) {
      return;
    }
    if (length < 0) {
      return null;
    }
    const responses = new Array(length);
    return parseArrayElements(parser, responses, 0);
  }
  function pushArrayCache(parser, array, pos) {
    parser.arrayCache.push(array);
    parser.arrayPos.push(pos);
  }
  function parseArrayChunks(parser) {
    const tmp = parser.arrayCache.pop();
    var pos = parser.arrayPos.pop();
    if (parser.arrayCache.length) {
      const res = parseArrayChunks(parser);
      if (res === undefined) {
        pushArrayCache(parser, tmp, pos);
        return;
      }
      tmp[pos++] = res;
    }
    return parseArrayElements(parser, tmp, pos);
  }
  function parseArrayElements(parser, responses, i) {
    const bufferLength = parser.buffer.length;
    while (i < responses.length) {
      const offset = parser.offset;
      if (parser.offset >= bufferLength) {
        pushArrayCache(parser, responses, i);
        return;
      }
      const response = parseType(parser, parser.buffer[parser.offset++]);
      if (response === undefined) {
        if (!(parser.arrayCache.length || parser.bufferCache.length)) {
          parser.offset = offset;
        }
        pushArrayCache(parser, responses, i);
        return;
      }
      responses[i] = response;
      i++;
    }
    return responses;
  }
  function parseType(parser, type) {
    switch (type) {
      case 36:
        return parseBulkString(parser);
      case 43:
        return parseSimpleString(parser);
      case 42:
        return parseArray(parser);
      case 58:
        return parseInteger(parser);
      case 45:
        return parseError(parser);
      default:
        return handleError(parser, type);
    }
  }
  function decreaseBufferPool() {
    if (bufferPool.length > 50 * 1024) {
      if (counter === 1 || notDecreased > counter * 2) {
        const minSliceLen = Math.floor(bufferPool.length / 10);
        const sliceLength = minSliceLen < bufferOffset ? bufferOffset : minSliceLen;
        bufferOffset = 0;
        bufferPool = bufferPool.slice(sliceLength, bufferPool.length);
      } else {
        notDecreased++;
        counter--;
      }
    } else {
      clearInterval(interval);
      counter = 0;
      notDecreased = 0;
      interval = null;
    }
  }
  function resizeBuffer(length) {
    if (bufferPool.length < length + bufferOffset) {
      const multiplier = length > 1024 * 1024 * 75 ? 2 : 3;
      if (bufferOffset > 1024 * 1024 * 111) {
        bufferOffset = 1024 * 1024 * 50;
      }
      bufferPool = Buffer2.allocUnsafe(length * multiplier + bufferOffset);
      bufferOffset = 0;
      counter++;
      if (interval === null) {
        interval = setInterval(decreaseBufferPool, 50);
      }
    }
  }
  function concatBulkString(parser) {
    const list = parser.bufferCache;
    const oldOffset = parser.offset;
    var chunks = list.length;
    var offset = parser.bigStrSize - parser.totalChunkSize;
    parser.offset = offset;
    if (offset <= 2) {
      if (chunks === 2) {
        return list[0].toString("utf8", oldOffset, list[0].length + offset - 2);
      }
      chunks--;
      offset = list[list.length - 2].length + offset;
    }
    var res = decoder.write(list[0].slice(oldOffset));
    for (var i = 1;i < chunks - 1; i++) {
      res += decoder.write(list[i]);
    }
    res += decoder.end(list[i].slice(0, offset - 2));
    return res;
  }
  function concatBulkBuffer(parser) {
    const list = parser.bufferCache;
    const oldOffset = parser.offset;
    const length = parser.bigStrSize - oldOffset - 2;
    var chunks = list.length;
    var offset = parser.bigStrSize - parser.totalChunkSize;
    parser.offset = offset;
    if (offset <= 2) {
      if (chunks === 2) {
        return list[0].slice(oldOffset, list[0].length + offset - 2);
      }
      chunks--;
      offset = list[list.length - 2].length + offset;
    }
    resizeBuffer(length);
    const start = bufferOffset;
    list[0].copy(bufferPool, start, oldOffset, list[0].length);
    bufferOffset += list[0].length - oldOffset;
    for (var i = 1;i < chunks - 1; i++) {
      list[i].copy(bufferPool, bufferOffset);
      bufferOffset += list[i].length;
    }
    list[i].copy(bufferPool, bufferOffset, 0, offset - 2);
    bufferOffset += offset - 2;
    return bufferPool.slice(start, bufferOffset);
  }

  class JavascriptRedisParser {
    constructor(options) {
      if (!options) {
        throw new TypeError("Options are mandatory.");
      }
      if (typeof options.returnError !== "function" || typeof options.returnReply !== "function") {
        throw new TypeError("The returnReply and returnError options have to be functions.");
      }
      this.setReturnBuffers(!!options.returnBuffers);
      this.setStringNumbers(!!options.stringNumbers);
      this.returnError = options.returnError;
      this.returnFatalError = options.returnFatalError || options.returnError;
      this.returnReply = options.returnReply;
      this.reset();
    }
    reset() {
      this.offset = 0;
      this.buffer = null;
      this.bigStrSize = 0;
      this.totalChunkSize = 0;
      this.bufferCache = [];
      this.arrayCache = [];
      this.arrayPos = [];
    }
    setReturnBuffers(returnBuffers) {
      if (typeof returnBuffers !== "boolean") {
        throw new TypeError("The returnBuffers argument has to be a boolean");
      }
      this.optionReturnBuffers = returnBuffers;
    }
    setStringNumbers(stringNumbers) {
      if (typeof stringNumbers !== "boolean") {
        throw new TypeError("The stringNumbers argument has to be a boolean");
      }
      this.optionStringNumbers = stringNumbers;
    }
    execute(buffer) {
      if (this.buffer === null) {
        this.buffer = buffer;
        this.offset = 0;
      } else if (this.bigStrSize === 0) {
        const oldLength = this.buffer.length;
        const remainingLength = oldLength - this.offset;
        const newBuffer = Buffer2.allocUnsafe(remainingLength + buffer.length);
        this.buffer.copy(newBuffer, 0, this.offset, oldLength);
        buffer.copy(newBuffer, remainingLength, 0, buffer.length);
        this.buffer = newBuffer;
        this.offset = 0;
        if (this.arrayCache.length) {
          const arr = parseArrayChunks(this);
          if (arr === undefined) {
            return;
          }
          this.returnReply(arr);
        }
      } else if (this.totalChunkSize + buffer.length >= this.bigStrSize) {
        this.bufferCache.push(buffer);
        var tmp = this.optionReturnBuffers ? concatBulkBuffer(this) : concatBulkString(this);
        this.bigStrSize = 0;
        this.bufferCache = [];
        this.buffer = buffer;
        if (this.arrayCache.length) {
          this.arrayCache[0][this.arrayPos[0]++] = tmp;
          tmp = parseArrayChunks(this);
          if (tmp === undefined) {
            return;
          }
        }
        this.returnReply(tmp);
      } else {
        this.bufferCache.push(buffer);
        this.totalChunkSize += buffer.length;
        return;
      }
      while (this.offset < this.buffer.length) {
        const offset = this.offset;
        const type = this.buffer[this.offset++];
        const response = parseType(this, type);
        if (response === undefined) {
          if (!(this.arrayCache.length || this.bufferCache.length)) {
            this.offset = offset;
          }
          return;
        }
        if (type === 45) {
          this.returnError(response);
        } else {
          this.returnReply(response);
        }
      }
      this.buffer = null;
    }
  }
  module.exports = JavascriptRedisParser;
});

// node_modules/ioredis/built/SubscriptionSet.js
var require_SubscriptionSet = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });

  class SubscriptionSet {
    constructor() {
      this.set = {
        subscribe: {},
        psubscribe: {},
        ssubscribe: {}
      };
    }
    add(set, channel) {
      this.set[mapSet(set)][channel] = true;
    }
    del(set, channel) {
      delete this.set[mapSet(set)][channel];
    }
    channels(set) {
      return Object.keys(this.set[mapSet(set)]);
    }
    isEmpty() {
      return this.channels("subscribe").length === 0 && this.channels("psubscribe").length === 0 && this.channels("ssubscribe").length === 0;
    }
  }
  exports.default = SubscriptionSet;
  function mapSet(set) {
    if (set === "unsubscribe") {
      return "subscribe";
    }
    if (set === "punsubscribe") {
      return "psubscribe";
    }
    if (set === "sunsubscribe") {
      return "ssubscribe";
    }
    return set;
  }
});

// node_modules/ioredis/built/DataHandler.js
var require_DataHandler = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var Command_1 = require_Command();
  var utils_1 = require_utils2();
  var RedisParser = require_parser();
  var SubscriptionSet_1 = require_SubscriptionSet();
  var debug = (0, utils_1.Debug)("dataHandler");

  class DataHandler {
    constructor(redis, parserOptions) {
      this.redis = redis;
      const parser = new RedisParser({
        stringNumbers: parserOptions.stringNumbers,
        returnBuffers: true,
        returnError: (err) => {
          this.returnError(err);
        },
        returnFatalError: (err) => {
          this.returnFatalError(err);
        },
        returnReply: (reply) => {
          this.returnReply(reply);
        }
      });
      redis.stream.prependListener("data", (data) => {
        parser.execute(data);
      });
      redis.stream.resume();
    }
    returnFatalError(err) {
      err.message += ". Please report this.";
      this.redis.recoverFromFatalError(err, err, { offlineQueue: false });
    }
    returnError(err) {
      const item = this.shiftCommand(err);
      if (!item) {
        return;
      }
      err.command = {
        name: item.command.name,
        args: item.command.args
      };
      if (item.command.name == "ssubscribe" && err.message.includes("MOVED")) {
        this.redis.emit("moved");
        return;
      }
      this.redis.handleReconnection(err, item);
    }
    returnReply(reply) {
      if (this.handleMonitorReply(reply)) {
        return;
      }
      if (this.handleSubscriberReply(reply)) {
        return;
      }
      const item = this.shiftCommand(reply);
      if (!item) {
        return;
      }
      if (Command_1.default.checkFlag("ENTER_SUBSCRIBER_MODE", item.command.name)) {
        this.redis.condition.subscriber = new SubscriptionSet_1.default;
        this.redis.condition.subscriber.add(item.command.name, reply[1].toString());
        if (!fillSubCommand(item.command, reply[2])) {
          this.redis.commandQueue.unshift(item);
        }
      } else if (Command_1.default.checkFlag("EXIT_SUBSCRIBER_MODE", item.command.name)) {
        if (!fillUnsubCommand(item.command, reply[2])) {
          this.redis.commandQueue.unshift(item);
        }
      } else {
        item.command.resolve(reply);
      }
    }
    handleSubscriberReply(reply) {
      if (!this.redis.condition.subscriber) {
        return false;
      }
      const replyType = Array.isArray(reply) ? reply[0].toString() : null;
      debug('receive reply "%s" in subscriber mode', replyType);
      switch (replyType) {
        case "message":
          if (this.redis.listeners("message").length > 0) {
            this.redis.emit("message", reply[1].toString(), reply[2] ? reply[2].toString() : "");
          }
          this.redis.emit("messageBuffer", reply[1], reply[2]);
          break;
        case "pmessage": {
          const pattern = reply[1].toString();
          if (this.redis.listeners("pmessage").length > 0) {
            this.redis.emit("pmessage", pattern, reply[2].toString(), reply[3].toString());
          }
          this.redis.emit("pmessageBuffer", pattern, reply[2], reply[3]);
          break;
        }
        case "smessage": {
          if (this.redis.listeners("smessage").length > 0) {
            this.redis.emit("smessage", reply[1].toString(), reply[2] ? reply[2].toString() : "");
          }
          this.redis.emit("smessageBuffer", reply[1], reply[2]);
          break;
        }
        case "ssubscribe":
        case "subscribe":
        case "psubscribe": {
          const channel = reply[1].toString();
          this.redis.condition.subscriber.add(replyType, channel);
          const item = this.shiftCommand(reply);
          if (!item) {
            return;
          }
          if (!fillSubCommand(item.command, reply[2])) {
            this.redis.commandQueue.unshift(item);
          }
          break;
        }
        case "sunsubscribe":
        case "unsubscribe":
        case "punsubscribe": {
          const channel = reply[1] ? reply[1].toString() : null;
          if (channel) {
            this.redis.condition.subscriber.del(replyType, channel);
          }
          const count = reply[2];
          if (Number(count) === 0) {
            this.redis.condition.subscriber = false;
          }
          const item = this.shiftCommand(reply);
          if (!item) {
            return;
          }
          if (!fillUnsubCommand(item.command, count)) {
            this.redis.commandQueue.unshift(item);
          }
          break;
        }
        default: {
          const item = this.shiftCommand(reply);
          if (!item) {
            return;
          }
          item.command.resolve(reply);
        }
      }
      return true;
    }
    handleMonitorReply(reply) {
      if (this.redis.status !== "monitoring") {
        return false;
      }
      const replyStr = reply.toString();
      if (replyStr === "OK") {
        return false;
      }
      const len = replyStr.indexOf(" ");
      const timestamp = replyStr.slice(0, len);
      const argIndex = replyStr.indexOf('"');
      const args = replyStr.slice(argIndex + 1, -1).split('" "').map((elem) => elem.replace(/\\"/g, '"'));
      const dbAndSource = replyStr.slice(len + 2, argIndex - 2).split(" ");
      this.redis.emit("monitor", timestamp, args, dbAndSource[1], dbAndSource[0]);
      return true;
    }
    shiftCommand(reply) {
      const item = this.redis.commandQueue.shift();
      if (!item) {
        const message = "Command queue state error. If you can reproduce this, please report it.";
        const error = new Error(message + (reply instanceof Error ? ` Last error: ${reply.message}` : ` Last reply: ${reply.toString()}`));
        this.redis.emit("error", error);
        return null;
      }
      return item;
    }
  }
  exports.default = DataHandler;
  var remainingRepliesMap = new WeakMap;
  function fillSubCommand(command, count) {
    let remainingReplies = remainingRepliesMap.has(command) ? remainingRepliesMap.get(command) : command.args.length;
    remainingReplies -= 1;
    if (remainingReplies <= 0) {
      command.resolve(count);
      remainingRepliesMap.delete(command);
      return true;
    }
    remainingRepliesMap.set(command, remainingReplies);
    return false;
  }
  function fillUnsubCommand(command, count) {
    let remainingReplies = remainingRepliesMap.has(command) ? remainingRepliesMap.get(command) : command.args.length;
    if (remainingReplies === 0) {
      if (Number(count) === 0) {
        remainingRepliesMap.delete(command);
        command.resolve(count);
        return true;
      }
      return false;
    }
    remainingReplies -= 1;
    if (remainingReplies <= 0) {
      command.resolve(count);
      return true;
    }
    remainingRepliesMap.set(command, remainingReplies);
    return false;
  }
});

// node_modules/ioredis/built/redis/event_handler.js
var require_event_handler = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.readyHandler = exports.errorHandler = exports.closeHandler = exports.connectHandler = undefined;
  var redis_errors_1 = require_redis_errors();
  var Command_1 = require_Command();
  var errors_1 = require_errors();
  var utils_1 = require_utils2();
  var DataHandler_1 = require_DataHandler();
  var debug = (0, utils_1.Debug)("connection");
  function connectHandler(self) {
    return function() {
      var _a;
      self.setStatus("connect");
      self.resetCommandQueue();
      let flushed = false;
      const { connectionEpoch } = self;
      if (self.condition.auth) {
        self.auth(self.condition.auth, function(err) {
          if (connectionEpoch !== self.connectionEpoch) {
            return;
          }
          if (err) {
            if (err.message.indexOf("no password is set") !== -1) {
              console.warn("[WARN] Redis server does not require a password, but a password was supplied.");
            } else if (err.message.indexOf("without any password configured for the default user") !== -1) {
              console.warn("[WARN] This Redis server's `default` user does not require a password, but a password was supplied");
            } else if (err.message.indexOf("wrong number of arguments for 'auth' command") !== -1) {
              console.warn(`[ERROR] The server returned "wrong number of arguments for 'auth' command". You are probably passing both username and password to Redis version 5 or below. You should only pass the 'password' option for Redis version 5 and under.`);
            } else {
              flushed = true;
              self.recoverFromFatalError(err, err);
            }
          }
        });
      }
      if (self.condition.select) {
        self.select(self.condition.select).catch((err) => {
          self.silentEmit("error", err);
        });
      }
      new DataHandler_1.default(self, {
        stringNumbers: self.options.stringNumbers
      });
      const clientCommandPromises = [];
      if (self.options.connectionName) {
        debug("set the connection name [%s]", self.options.connectionName);
        clientCommandPromises.push(self.client("setname", self.options.connectionName).catch(utils_1.noop));
      }
      if (!self.options.disableClientInfo) {
        debug("set the client info");
        clientCommandPromises.push((0, utils_1.getPackageMeta)().then((packageMeta) => {
          return self.client("SETINFO", "LIB-VER", packageMeta.version).catch(utils_1.noop);
        }).catch(utils_1.noop));
        clientCommandPromises.push(self.client("SETINFO", "LIB-NAME", ((_a = self.options) === null || _a === undefined ? undefined : _a.clientInfoTag) ? `ioredis(${self.options.clientInfoTag})` : "ioredis").catch(utils_1.noop));
      }
      Promise.all(clientCommandPromises).catch(utils_1.noop).finally(() => {
        if (!self.options.enableReadyCheck) {
          exports.readyHandler(self)();
        }
        if (self.options.enableReadyCheck) {
          self._readyCheck(function(err, info) {
            if (connectionEpoch !== self.connectionEpoch) {
              return;
            }
            if (err) {
              if (!flushed) {
                self.recoverFromFatalError(new Error("Ready check failed: " + err.message), err);
              }
            } else {
              if (self.connector.check(info)) {
                exports.readyHandler(self)();
              } else {
                self.disconnect(true);
              }
            }
          });
        }
      });
    };
  }
  exports.connectHandler = connectHandler;
  function abortError(command) {
    const err = new redis_errors_1.AbortError("Command aborted due to connection close");
    err.command = {
      name: command.name,
      args: command.args
    };
    return err;
  }
  function abortIncompletePipelines(commandQueue) {
    var _a;
    let expectedIndex = 0;
    for (let i = 0;i < commandQueue.length; ) {
      const command = (_a = commandQueue.peekAt(i)) === null || _a === undefined ? undefined : _a.command;
      const pipelineIndex = command.pipelineIndex;
      if (pipelineIndex === undefined || pipelineIndex === 0) {
        expectedIndex = 0;
      }
      if (pipelineIndex !== undefined && pipelineIndex !== expectedIndex++) {
        commandQueue.remove(i, 1);
        command.reject(abortError(command));
        continue;
      }
      i++;
    }
  }
  function abortTransactionFragments(commandQueue) {
    var _a;
    for (let i = 0;i < commandQueue.length; ) {
      const command = (_a = commandQueue.peekAt(i)) === null || _a === undefined ? undefined : _a.command;
      if (command.name === "multi") {
        break;
      }
      if (command.name === "exec") {
        commandQueue.remove(i, 1);
        command.reject(abortError(command));
        break;
      }
      if (command.inTransaction) {
        commandQueue.remove(i, 1);
        command.reject(abortError(command));
      } else {
        i++;
      }
    }
  }
  function closeHandler(self) {
    return function() {
      const prevStatus = self.status;
      self.setStatus("close");
      if (self.commandQueue.length) {
        abortIncompletePipelines(self.commandQueue);
      }
      if (self.offlineQueue.length) {
        abortTransactionFragments(self.offlineQueue);
      }
      if (prevStatus === "ready") {
        if (!self.prevCondition) {
          self.prevCondition = self.condition;
        }
        if (self.commandQueue.length) {
          self.prevCommandQueue = self.commandQueue;
        }
      }
      if (self.manuallyClosing) {
        self.manuallyClosing = false;
        debug("skip reconnecting since the connection is manually closed.");
        return close();
      }
      if (typeof self.options.retryStrategy !== "function") {
        debug("skip reconnecting because `retryStrategy` is not a function");
        return close();
      }
      const retryDelay = self.options.retryStrategy(++self.retryAttempts);
      if (typeof retryDelay !== "number") {
        debug("skip reconnecting because `retryStrategy` doesn't return a number");
        return close();
      }
      debug("reconnect in %sms", retryDelay);
      self.setStatus("reconnecting", retryDelay);
      self.reconnectTimeout = setTimeout(function() {
        self.reconnectTimeout = null;
        self.connect().catch(utils_1.noop);
      }, retryDelay);
      const { maxRetriesPerRequest } = self.options;
      if (typeof maxRetriesPerRequest === "number") {
        if (maxRetriesPerRequest < 0) {
          debug("maxRetriesPerRequest is negative, ignoring...");
        } else {
          const remainder = self.retryAttempts % (maxRetriesPerRequest + 1);
          if (remainder === 0) {
            debug("reach maxRetriesPerRequest limitation, flushing command queue...");
            self.flushQueue(new errors_1.MaxRetriesPerRequestError(maxRetriesPerRequest));
          }
        }
      }
    };
    function close() {
      self.setStatus("end");
      self.flushQueue(new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG));
    }
  }
  exports.closeHandler = closeHandler;
  function errorHandler(self) {
    return function(error) {
      debug("error: %s", error);
      self.silentEmit("error", error);
    };
  }
  exports.errorHandler = errorHandler;
  function readyHandler(self) {
    return function() {
      self.setStatus("ready");
      self.retryAttempts = 0;
      if (self.options.monitor) {
        self.call("monitor").then(() => self.setStatus("monitoring"), (error) => self.emit("error", error));
        const { sendCommand } = self;
        self.sendCommand = function(command) {
          if (Command_1.default.checkFlag("VALID_IN_MONITOR_MODE", command.name)) {
            return sendCommand.call(self, command);
          }
          command.reject(new Error("Connection is in monitoring mode, can't process commands."));
          return command.promise;
        };
        self.once("close", function() {
          delete self.sendCommand;
        });
        return;
      }
      const finalSelect = self.prevCondition ? self.prevCondition.select : self.condition.select;
      if (self.options.readOnly) {
        debug("set the connection to readonly mode");
        self.readonly().catch(utils_1.noop);
      }
      if (self.prevCondition) {
        const condition = self.prevCondition;
        self.prevCondition = null;
        if (condition.subscriber && self.options.autoResubscribe) {
          if (self.condition.select !== finalSelect) {
            debug("connect to db [%d]", finalSelect);
            self.select(finalSelect);
          }
          const subscribeChannels = condition.subscriber.channels("subscribe");
          if (subscribeChannels.length) {
            debug("subscribe %d channels", subscribeChannels.length);
            self.subscribe(subscribeChannels);
          }
          const psubscribeChannels = condition.subscriber.channels("psubscribe");
          if (psubscribeChannels.length) {
            debug("psubscribe %d channels", psubscribeChannels.length);
            self.psubscribe(psubscribeChannels);
          }
          const ssubscribeChannels = condition.subscriber.channels("ssubscribe");
          if (ssubscribeChannels.length) {
            debug("ssubscribe %s", ssubscribeChannels.length);
            for (const channel of ssubscribeChannels) {
              self.ssubscribe(channel);
            }
          }
        }
      }
      if (self.prevCommandQueue) {
        if (self.options.autoResendUnfulfilledCommands) {
          debug("resend %d unfulfilled commands", self.prevCommandQueue.length);
          while (self.prevCommandQueue.length > 0) {
            const item = self.prevCommandQueue.shift();
            if (item.select !== self.condition.select && item.command.name !== "select") {
              self.select(item.select);
            }
            self.sendCommand(item.command, item.stream);
          }
        } else {
          self.prevCommandQueue = null;
        }
      }
      if (self.offlineQueue.length) {
        debug("send %d commands in offline queue", self.offlineQueue.length);
        const offlineQueue = self.offlineQueue;
        self.resetOfflineQueue();
        while (offlineQueue.length > 0) {
          const item = offlineQueue.shift();
          if (item.select !== self.condition.select && item.command.name !== "select") {
            self.select(item.select);
          }
          self.sendCommand(item.command, item.stream);
        }
      }
      if (self.condition.select !== finalSelect) {
        debug("connect to db [%d]", finalSelect);
        self.select(finalSelect);
      }
    };
  }
  exports.readyHandler = readyHandler;
});

// node_modules/ioredis/built/redis/RedisOptions.js
var require_RedisOptions = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.DEFAULT_REDIS_OPTIONS = undefined;
  exports.DEFAULT_REDIS_OPTIONS = {
    port: 6379,
    host: "localhost",
    family: 0,
    connectTimeout: 1e4,
    disconnectTimeout: 2000,
    retryStrategy: function(times) {
      return Math.min(times * 50, 2000);
    },
    keepAlive: 0,
    noDelay: true,
    connectionName: null,
    disableClientInfo: false,
    clientInfoTag: undefined,
    sentinels: null,
    name: null,
    role: "master",
    sentinelRetryStrategy: function(times) {
      return Math.min(times * 10, 1000);
    },
    sentinelReconnectStrategy: function() {
      return 60000;
    },
    natMap: null,
    enableTLSForSentinelMode: false,
    updateSentinels: true,
    failoverDetector: false,
    username: null,
    password: null,
    db: 0,
    enableOfflineQueue: true,
    enableReadyCheck: true,
    autoResubscribe: true,
    autoResendUnfulfilledCommands: true,
    lazyConnect: false,
    keyPrefix: "",
    reconnectOnError: null,
    readOnly: false,
    stringNumbers: false,
    maxRetriesPerRequest: 20,
    maxLoadingRetryTime: 1e4,
    enableAutoPipelining: false,
    autoPipeliningIgnoredCommands: [],
    sentinelMaxConnections: 10,
    blockingTimeoutGrace: 100
  };
});

// node_modules/ioredis/built/Redis.js
var require_Redis = __commonJS((exports) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  var commands_1 = require_built();
  var events_1 = __require("events");
  var standard_as_callback_1 = require_built2();
  var cluster_1 = require_cluster();
  var Command_1 = require_Command();
  var connectors_1 = require_connectors();
  var SentinelConnector_1 = require_SentinelConnector();
  var eventHandler = require_event_handler();
  var RedisOptions_1 = require_RedisOptions();
  var ScanStream_1 = require_ScanStream();
  var transaction_1 = require_transaction();
  var utils_1 = require_utils2();
  var applyMixin_1 = require_applyMixin();
  var Commander_1 = require_Commander();
  var lodash_1 = require_lodash3();
  var Deque = require_denque();
  var debug = (0, utils_1.Debug)("redis");

  class Redis extends Commander_1.default {
    constructor(arg1, arg2, arg3) {
      super();
      this.status = "wait";
      this.isCluster = false;
      this.reconnectTimeout = null;
      this.connectionEpoch = 0;
      this.retryAttempts = 0;
      this.manuallyClosing = false;
      this._autoPipelines = new Map;
      this._runningAutoPipelines = new Set;
      this.parseOptions(arg1, arg2, arg3);
      events_1.EventEmitter.call(this);
      this.resetCommandQueue();
      this.resetOfflineQueue();
      if (this.options.Connector) {
        this.connector = new this.options.Connector(this.options);
      } else if (this.options.sentinels) {
        const sentinelConnector = new SentinelConnector_1.default(this.options);
        sentinelConnector.emitter = this;
        this.connector = sentinelConnector;
      } else {
        this.connector = new connectors_1.StandaloneConnector(this.options);
      }
      if (this.options.scripts) {
        Object.entries(this.options.scripts).forEach(([name, definition]) => {
          this.defineCommand(name, definition);
        });
      }
      if (this.options.lazyConnect) {
        this.setStatus("wait");
      } else {
        this.connect().catch(lodash_1.noop);
      }
    }
    static createClient(...args) {
      return new Redis(...args);
    }
    get autoPipelineQueueSize() {
      let queued = 0;
      for (const pipeline of this._autoPipelines.values()) {
        queued += pipeline.length;
      }
      return queued;
    }
    connect(callback) {
      const promise = new Promise((resolve, reject) => {
        if (this.status === "connecting" || this.status === "connect" || this.status === "ready") {
          reject(new Error("Redis is already connecting/connected"));
          return;
        }
        this.connectionEpoch += 1;
        this.setStatus("connecting");
        const { options } = this;
        this.condition = {
          select: options.db,
          auth: options.username ? [options.username, options.password] : options.password,
          subscriber: false
        };
        const _this = this;
        (0, standard_as_callback_1.default)(this.connector.connect(function(type, err) {
          _this.silentEmit(type, err);
        }), function(err, stream) {
          if (err) {
            _this.flushQueue(err);
            _this.silentEmit("error", err);
            reject(err);
            _this.setStatus("end");
            return;
          }
          let CONNECT_EVENT = options.tls ? "secureConnect" : "connect";
          if ("sentinels" in options && options.sentinels && !options.enableTLSForSentinelMode) {
            CONNECT_EVENT = "connect";
          }
          _this.stream = stream;
          if (options.noDelay) {
            stream.setNoDelay(true);
          }
          if (typeof options.keepAlive === "number") {
            if (stream.connecting) {
              stream.once(CONNECT_EVENT, () => {
                stream.setKeepAlive(true, options.keepAlive);
              });
            } else {
              stream.setKeepAlive(true, options.keepAlive);
            }
          }
          if (stream.connecting) {
            stream.once(CONNECT_EVENT, eventHandler.connectHandler(_this));
            if (options.connectTimeout) {
              let connectTimeoutCleared = false;
              stream.setTimeout(options.connectTimeout, function() {
                if (connectTimeoutCleared) {
                  return;
                }
                stream.setTimeout(0);
                stream.destroy();
                const err2 = new Error("connect ETIMEDOUT");
                err2.errorno = "ETIMEDOUT";
                err2.code = "ETIMEDOUT";
                err2.syscall = "connect";
                eventHandler.errorHandler(_this)(err2);
              });
              stream.once(CONNECT_EVENT, function() {
                connectTimeoutCleared = true;
                stream.setTimeout(0);
              });
            }
          } else if (stream.destroyed) {
            const firstError = _this.connector.firstError;
            if (firstError) {
              process.nextTick(() => {
                eventHandler.errorHandler(_this)(firstError);
              });
            }
            process.nextTick(eventHandler.closeHandler(_this));
          } else {
            process.nextTick(eventHandler.connectHandler(_this));
          }
          if (!stream.destroyed) {
            stream.once("error", eventHandler.errorHandler(_this));
            stream.once("close", eventHandler.closeHandler(_this));
          }
          const connectionReadyHandler = function() {
            _this.removeListener("close", connectionCloseHandler);
            resolve();
          };
          var connectionCloseHandler = function() {
            _this.removeListener("ready", connectionReadyHandler);
            reject(new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG));
          };
          _this.once("ready", connectionReadyHandler);
          _this.once("close", connectionCloseHandler);
        });
      });
      return (0, standard_as_callback_1.default)(promise, callback);
    }
    disconnect(reconnect = false) {
      if (!reconnect) {
        this.manuallyClosing = true;
      }
      if (this.reconnectTimeout && !reconnect) {
        clearTimeout(this.reconnectTimeout);
        this.reconnectTimeout = null;
      }
      if (this.status === "wait") {
        eventHandler.closeHandler(this)();
      } else {
        this.connector.disconnect();
      }
    }
    end() {
      this.disconnect();
    }
    duplicate(override) {
      return new Redis({ ...this.options, ...override });
    }
    get mode() {
      var _a;
      return this.options.monitor ? "monitor" : ((_a = this.condition) === null || _a === undefined ? undefined : _a.subscriber) ? "subscriber" : "normal";
    }
    monitor(callback) {
      const monitorInstance = this.duplicate({
        monitor: true,
        lazyConnect: false
      });
      return (0, standard_as_callback_1.default)(new Promise(function(resolve, reject) {
        monitorInstance.once("error", reject);
        monitorInstance.once("monitoring", function() {
          resolve(monitorInstance);
        });
      }), callback);
    }
    sendCommand(command, stream) {
      var _a, _b;
      if (this.status === "wait") {
        this.connect().catch(lodash_1.noop);
      }
      if (this.status === "end") {
        command.reject(new Error(utils_1.CONNECTION_CLOSED_ERROR_MSG));
        return command.promise;
      }
      if (((_a = this.condition) === null || _a === undefined ? undefined : _a.subscriber) && !Command_1.default.checkFlag("VALID_IN_SUBSCRIBER_MODE", command.name)) {
        command.reject(new Error("Connection in subscriber mode, only subscriber commands may be used"));
        return command.promise;
      }
      if (typeof this.options.commandTimeout === "number") {
        command.setTimeout(this.options.commandTimeout);
      }
      const blockingTimeout = this.getBlockingTimeoutInMs(command);
      let writable = this.status === "ready" || !stream && this.status === "connect" && (0, commands_1.exists)(command.name, { caseInsensitive: true }) && ((0, commands_1.hasFlag)(command.name, "loading", { nameCaseInsensitive: true }) || Command_1.default.checkFlag("HANDSHAKE_COMMANDS", command.name));
      if (!this.stream) {
        writable = false;
      } else if (!this.stream.writable) {
        writable = false;
      } else if (this.stream._writableState && this.stream._writableState.ended) {
        writable = false;
      }
      if (!writable) {
        if (!this.options.enableOfflineQueue) {
          command.reject(new Error("Stream isn't writeable and enableOfflineQueue options is false"));
          return command.promise;
        }
        if (command.name === "quit" && this.offlineQueue.length === 0) {
          this.disconnect();
          command.resolve(Buffer.from("OK"));
          return command.promise;
        }
        if (debug.enabled) {
          debug("queue command[%s]: %d -> %s(%o)", this._getDescription(), this.condition.select, command.name, command.args);
        }
        this.offlineQueue.push({
          command,
          stream,
          select: this.condition.select
        });
        if (Command_1.default.checkFlag("BLOCKING_COMMANDS", command.name)) {
          const offlineTimeout = this.getConfiguredBlockingTimeout();
          if (offlineTimeout !== undefined) {
            command.setBlockingTimeout(offlineTimeout);
          }
        }
      } else {
        if (debug.enabled) {
          debug("write command[%s]: %d -> %s(%o)", this._getDescription(), (_b = this.condition) === null || _b === undefined ? undefined : _b.select, command.name, command.args);
        }
        if (stream) {
          if ("isPipeline" in stream && stream.isPipeline) {
            stream.write(command.toWritable(stream.destination.redis.stream));
          } else {
            stream.write(command.toWritable(stream));
          }
        } else {
          this.stream.write(command.toWritable(this.stream));
        }
        this.commandQueue.push({
          command,
          stream,
          select: this.condition.select
        });
        if (blockingTimeout !== undefined) {
          command.setBlockingTimeout(blockingTimeout);
        }
        if (Command_1.default.checkFlag("WILL_DISCONNECT", command.name)) {
          this.manuallyClosing = true;
        }
        if (this.options.socketTimeout !== undefined && this.socketTimeoutTimer === undefined) {
          this.setSocketTimeout();
        }
      }
      if (command.name === "select" && (0, utils_1.isInt)(command.args[0])) {
        const db = parseInt(command.args[0], 10);
        if (this.condition.select !== db) {
          this.condition.select = db;
          this.emit("select", db);
          debug("switch to db [%d]", this.condition.select);
        }
      }
      return command.promise;
    }
    getBlockingTimeoutInMs(command) {
      var _a;
      if (!Command_1.default.checkFlag("BLOCKING_COMMANDS", command.name)) {
        return;
      }
      const configuredTimeout = this.getConfiguredBlockingTimeout();
      if (configuredTimeout === undefined) {
        return;
      }
      const timeout = command.extractBlockingTimeout();
      if (typeof timeout === "number") {
        if (timeout > 0) {
          return timeout + ((_a = this.options.blockingTimeoutGrace) !== null && _a !== undefined ? _a : RedisOptions_1.DEFAULT_REDIS_OPTIONS.blockingTimeoutGrace);
        }
        return configuredTimeout;
      }
      if (timeout === null) {
        return configuredTimeout;
      }
      return;
    }
    getConfiguredBlockingTimeout() {
      if (typeof this.options.blockingTimeout === "number" && this.options.blockingTimeout > 0) {
        return this.options.blockingTimeout;
      }
      return;
    }
    setSocketTimeout() {
      this.socketTimeoutTimer = setTimeout(() => {
        this.stream.destroy(new Error(`Socket timeout. Expecting data, but didn't receive any in ${this.options.socketTimeout}ms.`));
        this.socketTimeoutTimer = undefined;
      }, this.options.socketTimeout);
      this.stream.once("data", () => {
        clearTimeout(this.socketTimeoutTimer);
        this.socketTimeoutTimer = undefined;
        if (this.commandQueue.length === 0)
          return;
        this.setSocketTimeout();
      });
    }
    scanStream(options) {
      return this.createScanStream("scan", { options });
    }
    scanBufferStream(options) {
      return this.createScanStream("scanBuffer", { options });
    }
    sscanStream(key, options) {
      return this.createScanStream("sscan", { key, options });
    }
    sscanBufferStream(key, options) {
      return this.createScanStream("sscanBuffer", { key, options });
    }
    hscanStream(key, options) {
      return this.createScanStream("hscan", { key, options });
    }
    hscanBufferStream(key, options) {
      return this.createScanStream("hscanBuffer", { key, options });
    }
    zscanStream(key, options) {
      return this.createScanStream("zscan", { key, options });
    }
    zscanBufferStream(key, options) {
      return this.createScanStream("zscanBuffer", { key, options });
    }
    silentEmit(eventName, arg) {
      let error;
      if (eventName === "error") {
        error = arg;
        if (this.status === "end") {
          return;
        }
        if (this.manuallyClosing) {
          if (error instanceof Error && (error.message === utils_1.CONNECTION_CLOSED_ERROR_MSG || error.syscall === "connect" || error.syscall === "read")) {
            return;
          }
        }
      }
      if (this.listeners(eventName).length > 0) {
        return this.emit.apply(this, arguments);
      }
      if (error && error instanceof Error) {
        console.error("[ioredis] Unhandled error event:", error.stack);
      }
      return false;
    }
    recoverFromFatalError(_commandError, err, options) {
      this.flushQueue(err, options);
      this.silentEmit("error", err);
      this.disconnect(true);
    }
    handleReconnection(err, item) {
      var _a;
      let needReconnect = false;
      if (this.options.reconnectOnError && !Command_1.default.checkFlag("IGNORE_RECONNECT_ON_ERROR", item.command.name)) {
        needReconnect = this.options.reconnectOnError(err);
      }
      switch (needReconnect) {
        case 1:
        case true:
          if (this.status !== "reconnecting") {
            this.disconnect(true);
          }
          item.command.reject(err);
          break;
        case 2:
          if (this.status !== "reconnecting") {
            this.disconnect(true);
          }
          if (((_a = this.condition) === null || _a === undefined ? undefined : _a.select) !== item.select && item.command.name !== "select") {
            this.select(item.select);
          }
          this.sendCommand(item.command);
          break;
        default:
          item.command.reject(err);
      }
    }
    _getDescription() {
      let description;
      if ("path" in this.options && this.options.path) {
        description = this.options.path;
      } else if (this.stream && this.stream.remoteAddress && this.stream.remotePort) {
        description = this.stream.remoteAddress + ":" + this.stream.remotePort;
      } else if ("host" in this.options && this.options.host) {
        description = this.options.host + ":" + this.options.port;
      } else {
        description = "";
      }
      if (this.options.connectionName) {
        description += ` (${this.options.connectionName})`;
      }
      return description;
    }
    resetCommandQueue() {
      this.commandQueue = new Deque;
    }
    resetOfflineQueue() {
      this.offlineQueue = new Deque;
    }
    parseOptions(...args) {
      const options = {};
      let isTls = false;
      for (let i = 0;i < args.length; ++i) {
        const arg = args[i];
        if (arg === null || typeof arg === "undefined") {
          continue;
        }
        if (typeof arg === "object") {
          (0, lodash_1.defaults)(options, arg);
        } else if (typeof arg === "string") {
          (0, lodash_1.defaults)(options, (0, utils_1.parseURL)(arg));
          if (arg.startsWith("rediss://")) {
            isTls = true;
          }
        } else if (typeof arg === "number") {
          options.port = arg;
        } else {
          throw new Error("Invalid argument " + arg);
        }
      }
      if (isTls) {
        (0, lodash_1.defaults)(options, { tls: true });
      }
      (0, lodash_1.defaults)(options, Redis.defaultOptions);
      if (typeof options.port === "string") {
        options.port = parseInt(options.port, 10);
      }
      if (typeof options.db === "string") {
        options.db = parseInt(options.db, 10);
      }
      this.options = (0, utils_1.resolveTLSProfile)(options);
    }
    setStatus(status, arg) {
      if (debug.enabled) {
        debug("status[%s]: %s -> %s", this._getDescription(), this.status || "[empty]", status);
      }
      this.status = status;
      process.nextTick(this.emit.bind(this, status, arg));
    }
    createScanStream(command, { key, options = {} }) {
      return new ScanStream_1.default({
        objectMode: true,
        key,
        redis: this,
        command,
        ...options
      });
    }
    flushQueue(error, options) {
      options = (0, lodash_1.defaults)({}, options, {
        offlineQueue: true,
        commandQueue: true
      });
      let item;
      if (options.offlineQueue) {
        while (item = this.offlineQueue.shift()) {
          item.command.reject(error);
        }
      }
      if (options.commandQueue) {
        if (this.commandQueue.length > 0) {
          if (this.stream) {
            this.stream.removeAllListeners("data");
          }
          while (item = this.commandQueue.shift()) {
            item.command.reject(error);
          }
        }
      }
    }
    _readyCheck(callback) {
      const _this = this;
      this.info(function(err, res) {
        if (err) {
          if (err.message && err.message.includes("NOPERM")) {
            console.warn(`Skipping the ready check because INFO command fails: "${err.message}". You can disable ready check with "enableReadyCheck". More: https://github.com/luin/ioredis/wiki/Disable-ready-check.`);
            return callback(null, {});
          }
          return callback(err);
        }
        if (typeof res !== "string") {
          return callback(null, res);
        }
        const info = {};
        const lines = res.split(`\r
`);
        for (let i = 0;i < lines.length; ++i) {
          const [fieldName, ...fieldValueParts] = lines[i].split(":");
          const fieldValue = fieldValueParts.join(":");
          if (fieldValue) {
            info[fieldName] = fieldValue;
          }
        }
        if (!info.loading || info.loading === "0") {
          callback(null, info);
        } else {
          const loadingEtaMs = (info.loading_eta_seconds || 1) * 1000;
          const retryTime = _this.options.maxLoadingRetryTime && _this.options.maxLoadingRetryTime < loadingEtaMs ? _this.options.maxLoadingRetryTime : loadingEtaMs;
          debug("Redis server still loading, trying again in " + retryTime + "ms");
          setTimeout(function() {
            _this._readyCheck(callback);
          }, retryTime);
        }
      }).catch(lodash_1.noop);
    }
  }
  Redis.Cluster = cluster_1.default;
  Redis.Command = Command_1.default;
  Redis.defaultOptions = RedisOptions_1.DEFAULT_REDIS_OPTIONS;
  (0, applyMixin_1.default)(Redis, events_1.EventEmitter);
  (0, transaction_1.addTransactionSupport)(Redis.prototype);
  exports.default = Redis;
});

// node_modules/ioredis/built/index.js
var require_built3 = __commonJS((exports, module) => {
  Object.defineProperty(exports, "__esModule", { value: true });
  exports.print = exports.ReplyError = exports.SentinelIterator = exports.SentinelConnector = exports.AbstractConnector = exports.Pipeline = exports.ScanStream = exports.Command = exports.Cluster = exports.Redis = exports.default = undefined;
  exports = module.exports = require_Redis().default;
  var Redis_1 = require_Redis();
  Object.defineProperty(exports, "default", { enumerable: true, get: function() {
    return Redis_1.default;
  } });
  var Redis_2 = require_Redis();
  Object.defineProperty(exports, "Redis", { enumerable: true, get: function() {
    return Redis_2.default;
  } });
  var cluster_1 = require_cluster();
  Object.defineProperty(exports, "Cluster", { enumerable: true, get: function() {
    return cluster_1.default;
  } });
  var Command_1 = require_Command();
  Object.defineProperty(exports, "Command", { enumerable: true, get: function() {
    return Command_1.default;
  } });
  var ScanStream_1 = require_ScanStream();
  Object.defineProperty(exports, "ScanStream", { enumerable: true, get: function() {
    return ScanStream_1.default;
  } });
  var Pipeline_1 = require_Pipeline();
  Object.defineProperty(exports, "Pipeline", { enumerable: true, get: function() {
    return Pipeline_1.default;
  } });
  var AbstractConnector_1 = require_AbstractConnector();
  Object.defineProperty(exports, "AbstractConnector", { enumerable: true, get: function() {
    return AbstractConnector_1.default;
  } });
  var SentinelConnector_1 = require_SentinelConnector();
  Object.defineProperty(exports, "SentinelConnector", { enumerable: true, get: function() {
    return SentinelConnector_1.default;
  } });
  Object.defineProperty(exports, "SentinelIterator", { enumerable: true, get: function() {
    return SentinelConnector_1.SentinelIterator;
  } });
  exports.ReplyError = require_redis_errors().ReplyError;
  Object.defineProperty(exports, "Promise", {
    get() {
      console.warn("ioredis v5 does not support plugging third-party Promise library anymore. Native Promise will be used.");
      return Promise;
    },
    set(_lib) {
      console.warn("ioredis v5 does not support plugging third-party Promise library anymore. Native Promise will be used.");
    }
  });
  function print(err, reply) {
    if (err) {
      console.log("Error: " + err);
    } else {
      console.log("Reply: " + reply);
    }
  }
  exports.print = print;
});

// src/index.ts
import { Database } from "bun:sqlite";
import { createHash, createHmac } from "crypto";
import { existsSync, mkdirSync, readFileSync as readFileSync2 } from "fs";
import { dirname, resolve as resolve2 } from "path";

// src/config/default.ts
var default_default = {
  env: "default",
  host: "0.0.0.0",
  port: 8787,
  apiVersion: "v1",
  dbPath: "data/dev.sqlite",
  maxBodyBytes: 256 * 1024,
  rateLimit: {
    windowMs: 60000,
    maxPostsPerWindow: 60
  },
  tokenTtlMs: 24 * 60 * 60 * 1000
};

// src/config/dev.local.ts
var dev_local_default = {
  env: "development",
  dbPath: "data/dev.sqlite"
};

// src/config/prod.ts
var prod_default = {
  env: "production",
  dbPath: "data/prod.sqlite"
};

// src/db/redis.ts
var import_ioredis = __toESM(require_built3(), 1);
var DEFAULT_REDIS_URL = "redis://127.0.0.1:6379/0";
var redisUrl = Bun.env.REDIS_URL || DEFAULT_REDIS_URL;
var redis = new import_ioredis.default(redisUrl, {
  lazyConnect: true,
  maxRetriesPerRequest: 1,
  enableReadyCheck: true,
  enableOfflineQueue: false,
  connectTimeout: Number(Bun.env.REDIS_CONNECT_TIMEOUT_MS || 800),
  commandTimeout: Number(Bun.env.REDIS_COMMAND_TIMEOUT_MS || 1500),
  retryStrategy: (times) => Math.min(times * 200, 2000),
  reconnectOnError: (err) => {
    const message = err?.message || "";
    return message.includes("READONLY") || message.includes("ECONNRESET");
  }
});
redis.on("error", (err) => {
  console.warn("[redis] error", err);
});
redis.on("reconnecting", () => {
  console.warn("[redis] reconnecting");
});
function getRedis() {
  return redis;
}
async function ensureRedisReady() {
  try {
    if (redis.status !== "ready") {
      await redis.connect();
    }
    return redis.status === "ready";
  } catch {
    return false;
  }
}
async function pingRedis() {
  try {
    if (!await ensureRedisReady()) {
      return false;
    }
    const res = await redis.ping();
    return res == "PONG";
  } catch {
    return false;
  }
}
async function redisExample() {
  try {
    if (!await ensureRedisReady()) {
      throw new Error("Redis unavailable");
    }
    const cached = await redis.get("example:hello");
    if (!cached) {
      await redis.set("example:hello", "world", "EX", 60);
    }
    const value = await redis.get("example:hello");
    console.log("[redis] example value", value);
  } catch (err) {
    console.warn("[redis] example skipped", err);
  }
}

// src/auth/tokens.ts
var accessMemory = new Map;
var refreshMemory = new Map;
var revokedAccess = new Set;
var revokedRefresh = new Set;
var localOnlyRefresh = new Set;
var production = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((v) => ["production", "prod"].includes((v ?? "").toLowerCase()));
function accessKey(token) {
  return `access:${token}`;
}
function refreshKey(token) {
  return `refresh:${token}`;
}
function isExpired(record, now) {
  return record.expiresAt <= now;
}
async function issueAccessToken(userId, ttlMs) {
  const token = crypto.randomUUID();
  const now = Date.now();
  const record = { userId, createdAt: now, expiresAt: now + ttlMs };
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.set(accessKey(token), JSON.stringify(record), "PX", ttlMs);
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] access token write failed", err);
  }
  if (production && !persisted)
    throw new Error("Token storage unavailable");
  accessMemory.set(token, record);
  return token;
}
async function issueRefreshToken(userId, ttlMs, fingerprint) {
  const token = crypto.randomUUID();
  const now = Date.now();
  const record = { userId, createdAt: now, expiresAt: now + ttlMs, fingerprint };
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.set(refreshKey(token), JSON.stringify(record), "PX", ttlMs);
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] refresh token write failed", err);
  }
  if (production && !persisted)
    throw new Error("Token storage unavailable");
  if (!persisted)
    localOnlyRefresh.add(token);
  refreshMemory.set(token, record);
  return token;
}
async function issueTokenPair(userId, accessTtlMs, refreshTtlMs, fingerprint) {
  const accessToken = await issueAccessToken(userId, accessTtlMs);
  const refreshToken = await issueRefreshToken(userId, refreshTtlMs, fingerprint);
  return { accessToken, refreshToken };
}
async function getAccessToken(token) {
  if (revokedAccess.has(token))
    return null;
  const now = Date.now();
  const cached = accessMemory.get(token);
  if (cached && !isExpired(cached, now) && !production) {
    return cached;
  }
  if (cached && isExpired(cached, now)) {
    accessMemory.delete(token);
  }
  try {
    const redis2 = getRedis();
    if (!await ensureRedisReady()) {
      return null;
    }
    const raw = await redis2.get(accessKey(token));
    if (!raw) {
      return null;
    }
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed.userId != "string" || !Number.isFinite(parsed.expiresAt)) {
      return null;
    }
    if (isExpired(parsed, Date.now())) {
      await redis2.del(accessKey(token));
      return null;
    }
    accessMemory.set(token, parsed);
    return parsed;
  } catch (err) {
    console.warn("[auth] access token read failed", err);
    return null;
  }
}
async function revokeAccessToken(token) {
  revokedAccess.add(token);
  accessMemory.delete(token);
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.del(accessKey(token));
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] access token delete failed", err);
  }
  if (production && !persisted)
    throw new Error("Token revocation unavailable");
}
async function revokeRefreshToken(token) {
  revokedRefresh.add(token);
  localOnlyRefresh.delete(token);
  refreshMemory.delete(token);
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.del(refreshKey(token));
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] refresh token delete failed", err);
  }
  if (production && !persisted)
    throw new Error("Token revocation unavailable");
}
async function rotateRefreshToken(oldToken, refreshTtlMs, fingerprint) {
  if (!production && localOnlyRefresh.has(oldToken)) {
    const record = refreshMemory.get(oldToken);
    if (!record || revokedRefresh.has(oldToken) || isExpired(record, Date.now()))
      return null;
    localOnlyRefresh.delete(oldToken);
    revokedRefresh.add(oldToken);
    refreshMemory.delete(oldToken);
    const refreshToken2 = await issueRefreshToken(record.userId, refreshTtlMs, fingerprint ?? record.fingerprint);
    return { record, refreshToken: refreshToken2 };
  }
  if (!await ensureRedisReady())
    return null;
  const refreshToken = crypto.randomUUID();
  const now = Date.now();
  const script = `
		local raw = redis.call('GET', KEYS[1])
		if not raw then return nil end
		local ok, record = pcall(cjson.decode, raw)
		if not ok or type(record.userId) ~= 'string' or type(record.expiresAt) ~= 'number' or record.expiresAt <= tonumber(ARGV[1]) then return nil end
		local updated = {userId = record.userId, createdAt = tonumber(ARGV[1]), expiresAt = tonumber(ARGV[1]) + tonumber(ARGV[2])}
		if ARGV[3] ~= '' then updated.fingerprint = ARGV[3] elseif record.fingerprint then updated.fingerprint = record.fingerprint end
		redis.call('SET', KEYS[2], cjson.encode(updated), 'PX', ARGV[2])
		redis.call('DEL', KEYS[1])
		return raw`;
  try {
    const raw = await getRedis().eval(script, 2, refreshKey(oldToken), refreshKey(refreshToken), now, refreshTtlMs, fingerprint ?? "");
    if (typeof raw !== "string")
      return null;
    const record = JSON.parse(raw);
    revokedRefresh.add(oldToken);
    refreshMemory.delete(oldToken);
    refreshMemory.set(refreshToken, { userId: record.userId, createdAt: now, expiresAt: now + refreshTtlMs, fingerprint: fingerprint ?? record.fingerprint });
    return { record, refreshToken };
  } catch (err) {
    console.warn("[auth] refresh rotation failed", err);
    return null;
  }
}

// node_modules/postgres/src/index.js
import os from "os";
import fs from "fs";

// node_modules/postgres/src/query.js
var originCache = new Map;
var originStackCache = new Map;
var originError = Symbol("OriginError");
var CLOSE = {};

class Query extends Promise {
  constructor(strings, args, handler, canceller, options = {}) {
    let resolve, reject;
    super((a, b) => {
      resolve = a;
      reject = b;
    });
    this.tagged = Array.isArray(strings.raw);
    this.strings = strings;
    this.args = args;
    this.handler = handler;
    this.canceller = canceller;
    this.options = options;
    this.state = null;
    this.statement = null;
    this.resolve = (x) => (this.active = false, resolve(x));
    this.reject = (x) => (this.active = false, reject(x));
    this.active = false;
    this.cancelled = null;
    this.executed = false;
    this.signature = "";
    this[originError] = this.handler.debug ? new Error : this.tagged && cachedError(this.strings);
  }
  get origin() {
    return (this.handler.debug ? this[originError].stack : this.tagged && originStackCache.has(this.strings) ? originStackCache.get(this.strings) : originStackCache.set(this.strings, this[originError].stack).get(this.strings)) || "";
  }
  static get [Symbol.species]() {
    return Promise;
  }
  cancel() {
    return this.canceller && (this.canceller(this), this.canceller = null);
  }
  simple() {
    this.options.simple = true;
    this.options.prepare = false;
    return this;
  }
  async readable() {
    this.simple();
    this.streaming = true;
    return this;
  }
  async writable() {
    this.simple();
    this.streaming = true;
    return this;
  }
  cursor(rows = 1, fn) {
    this.options.simple = false;
    if (typeof rows === "function") {
      fn = rows;
      rows = 1;
    }
    this.cursorRows = rows;
    if (typeof fn === "function")
      return this.cursorFn = fn, this;
    let prev;
    return {
      [Symbol.asyncIterator]: () => ({
        next: () => {
          if (this.executed && !this.active)
            return { done: true };
          prev && prev();
          const promise = new Promise((resolve, reject) => {
            this.cursorFn = (value) => {
              resolve({ value, done: false });
              return new Promise((r) => prev = r);
            };
            this.resolve = () => (this.active = false, resolve({ done: true }));
            this.reject = (x) => (this.active = false, reject(x));
          });
          this.execute();
          return promise;
        },
        return() {
          prev && prev(CLOSE);
          return { done: true };
        }
      })
    };
  }
  describe() {
    this.options.simple = false;
    this.onlyDescribe = this.options.prepare = true;
    return this;
  }
  stream() {
    throw new Error(".stream has been renamed to .forEach");
  }
  forEach(fn) {
    this.forEachFn = fn;
    this.handle();
    return this;
  }
  raw() {
    this.isRaw = true;
    return this;
  }
  values() {
    this.isRaw = "values";
    return this;
  }
  async handle() {
    !this.executed && (this.executed = true) && await 1 && this.handler(this);
  }
  execute() {
    this.handle();
    return this;
  }
  then() {
    this.handle();
    return super.then.apply(this, arguments);
  }
  catch() {
    this.handle();
    return super.catch.apply(this, arguments);
  }
  finally() {
    this.handle();
    return super.finally.apply(this, arguments);
  }
}
function cachedError(xs) {
  if (originCache.has(xs))
    return originCache.get(xs);
  const x = Error.stackTraceLimit;
  Error.stackTraceLimit = 4;
  originCache.set(xs, new Error);
  Error.stackTraceLimit = x;
  return originCache.get(xs);
}

// node_modules/postgres/src/errors.js
class PostgresError extends Error {
  constructor(x) {
    super(x.message);
    this.name = this.constructor.name;
    Object.assign(this, x);
  }
}
var Errors = {
  connection,
  postgres,
  generic,
  notSupported
};
function connection(x, options, socket) {
  const { host, port } = socket || options;
  const error = Object.assign(new Error("write " + x + " " + (options.path || host + ":" + port)), {
    code: x,
    errno: x,
    address: options.path || host
  }, options.path ? {} : { port });
  Error.captureStackTrace(error, connection);
  return error;
}
function postgres(x) {
  const error = new PostgresError(x);
  Error.captureStackTrace(error, postgres);
  return error;
}
function generic(code, message) {
  const error = Object.assign(new Error(code + ": " + message), { code });
  Error.captureStackTrace(error, generic);
  return error;
}
function notSupported(x) {
  const error = Object.assign(new Error(x + " (B) is not supported"), {
    code: "MESSAGE_NOT_SUPPORTED",
    name: x
  });
  Error.captureStackTrace(error, notSupported);
  return error;
}

// node_modules/postgres/src/types.js
var types = {
  string: {
    to: 25,
    from: null,
    serialize: (x) => "" + x
  },
  number: {
    to: 0,
    from: [21, 23, 26, 700, 701],
    serialize: (x) => "" + x,
    parse: (x) => +x
  },
  json: {
    to: 114,
    from: [114, 3802],
    serialize: (x) => JSON.stringify(x),
    parse: (x) => JSON.parse(x)
  },
  boolean: {
    to: 16,
    from: 16,
    serialize: (x) => x === true ? "t" : "f",
    parse: (x) => x === "t"
  },
  date: {
    to: 1184,
    from: [1082, 1114, 1184],
    serialize: (x) => (x instanceof Date ? x : new Date(x)).toISOString(),
    parse: (x) => new Date(x)
  },
  bytea: {
    to: 17,
    from: 17,
    serialize: (x) => "\\x" + Buffer.from(x).toString("hex"),
    parse: (x) => Buffer.from(x.slice(2), "hex")
  }
};

class NotTagged {
  then() {
    notTagged();
  }
  catch() {
    notTagged();
  }
  finally() {
    notTagged();
  }
}

class Identifier extends NotTagged {
  constructor(value) {
    super();
    this.value = escapeIdentifier(value);
  }
}

class Parameter extends NotTagged {
  constructor(value, type, array) {
    super();
    this.value = value;
    this.type = type;
    this.array = array;
  }
}

class Builder extends NotTagged {
  constructor(first, rest) {
    super();
    this.first = first;
    this.rest = rest;
  }
  build(before, parameters, types2, options) {
    const keyword = builders.map(([x, fn]) => ({ fn, i: before.search(x) })).sort((a, b) => a.i - b.i).pop();
    return keyword.i === -1 ? escapeIdentifiers(this.first, options) : keyword.fn(this.first, this.rest, parameters, types2, options);
  }
}
function handleValue(x, parameters, types2, options) {
  let value = x instanceof Parameter ? x.value : x;
  if (value === undefined) {
    x instanceof Parameter ? x.value = options.transform.undefined : value = x = options.transform.undefined;
    if (value === undefined)
      throw Errors.generic("UNDEFINED_VALUE", "Undefined values are not allowed");
  }
  return "$" + types2.push(x instanceof Parameter ? (parameters.push(x.value), x.array ? x.array[x.type || inferType(x.value)] || x.type || firstIsString(x.value) : x.type) : (parameters.push(x), inferType(x)));
}
var defaultHandlers = typeHandlers(types);
function stringify(q, string, value, parameters, types2, options) {
  for (let i = 1;i < q.strings.length; i++) {
    string += stringifyValue(string, value, parameters, types2, options) + q.strings[i];
    value = q.args[i];
  }
  return string;
}
function stringifyValue(string, value, parameters, types2, o) {
  return value instanceof Builder ? value.build(string, parameters, types2, o) : value instanceof Query ? fragment(value, parameters, types2, o) : value instanceof Identifier ? value.value : value && value[0] instanceof Query ? value.reduce((acc, x) => acc + " " + fragment(x, parameters, types2, o), "") : handleValue(value, parameters, types2, o);
}
function fragment(q, parameters, types2, options) {
  q.fragment = true;
  return stringify(q, q.strings[0], q.args[0], parameters, types2, options);
}
function valuesBuilder(first, parameters, types2, columns, options) {
  return first.map((row) => "(" + columns.map((column) => stringifyValue("values", row[column], parameters, types2, options)).join(",") + ")").join(",");
}
function values(first, rest, parameters, types2, options) {
  const multi = Array.isArray(first[0]);
  const columns = rest.length ? rest.flat() : Object.keys(multi ? first[0] : first);
  return valuesBuilder(multi ? first : [first], parameters, types2, columns, options);
}
function select(first, rest, parameters, types2, options) {
  typeof first === "string" && (first = [first].concat(rest));
  if (Array.isArray(first))
    return escapeIdentifiers(first, options);
  let value;
  const columns = rest.length ? rest.flat() : Object.keys(first);
  return columns.map((x) => {
    value = first[x];
    return (value instanceof Query ? fragment(value, parameters, types2, options) : value instanceof Identifier ? value.value : handleValue(value, parameters, types2, options)) + " as " + escapeIdentifier(options.transform.column.to ? options.transform.column.to(x) : x);
  }).join(",");
}
var builders = Object.entries({
  values,
  in: (...xs) => {
    const x = values(...xs);
    return x === "()" ? "(null)" : x;
  },
  select,
  as: select,
  returning: select,
  "\\(": select,
  update(first, rest, parameters, types2, options) {
    return (rest.length ? rest.flat() : Object.keys(first)).map((x) => escapeIdentifier(options.transform.column.to ? options.transform.column.to(x) : x) + "=" + stringifyValue("values", first[x], parameters, types2, options));
  },
  insert(first, rest, parameters, types2, options) {
    const columns = rest.length ? rest.flat() : Object.keys(Array.isArray(first) ? first[0] : first);
    return "(" + escapeIdentifiers(columns, options) + ")values" + valuesBuilder(Array.isArray(first) ? first : [first], parameters, types2, columns, options);
  }
}).map(([x, fn]) => [new RegExp("((?:^|[\\s(])" + x + "(?:$|[\\s(]))(?![\\s\\S]*\\1)", "i"), fn]);
function notTagged() {
  throw Errors.generic("NOT_TAGGED_CALL", "Query not called as a tagged template literal");
}
var serializers = defaultHandlers.serializers;
var parsers = defaultHandlers.parsers;
function firstIsString(x) {
  if (Array.isArray(x))
    return firstIsString(x[0]);
  return typeof x === "string" ? 1009 : 0;
}
var mergeUserTypes = function(types2) {
  const user = typeHandlers(types2 || {});
  return {
    serializers: Object.assign({}, serializers, user.serializers),
    parsers: Object.assign({}, parsers, user.parsers)
  };
};
function typeHandlers(types2) {
  return Object.keys(types2).reduce((acc, k) => {
    types2[k].from && [].concat(types2[k].from).forEach((x) => acc.parsers[x] = types2[k].parse);
    if (types2[k].serialize) {
      acc.serializers[types2[k].to] = types2[k].serialize;
      types2[k].from && [].concat(types2[k].from).forEach((x) => acc.serializers[x] = types2[k].serialize);
    }
    return acc;
  }, { parsers: {}, serializers: {} });
}
function escapeIdentifiers(xs, { transform: { column } }) {
  return xs.map((x) => escapeIdentifier(column.to ? column.to(x) : x)).join(",");
}
var escapeIdentifier = function escape(str) {
  return '"' + str.replace(/"/g, '""').replace(/\./g, '"."') + '"';
};
var inferType = function inferType2(x) {
  return x instanceof Parameter ? x.type : x instanceof Date ? 1184 : x instanceof Uint8Array ? 17 : x === true || x === false ? 16 : typeof x === "bigint" ? 20 : Array.isArray(x) ? inferType2(x[0]) : 0;
};
var escapeBackslash = /\\/g;
var escapeQuote = /"/g;
function arrayEscape(x) {
  return x.replace(escapeBackslash, "\\\\").replace(escapeQuote, "\\\"");
}
var arraySerializer = function arraySerializer2(xs, serializer, options, typarray) {
  if (Array.isArray(xs) === false)
    return xs;
  if (!xs.length)
    return "{}";
  const first = xs[0];
  const delimiter = typarray === 1020 ? ";" : ",";
  if (Array.isArray(first) && !first.type)
    return "{" + xs.map((x) => arraySerializer2(x, serializer, options, typarray)).join(delimiter) + "}";
  return "{" + xs.map((x) => {
    if (x === undefined) {
      x = options.transform.undefined;
      if (x === undefined)
        throw Errors.generic("UNDEFINED_VALUE", "Undefined values are not allowed");
    }
    return x === null ? "null" : '"' + arrayEscape(serializer ? serializer(x.type ? x.value : x) : "" + x) + '"';
  }).join(delimiter) + "}";
};
var arrayParserState = {
  i: 0,
  char: null,
  str: "",
  quoted: false,
  last: 0
};
var arrayParser = function arrayParser2(x, parser, typarray) {
  arrayParserState.i = arrayParserState.last = 0;
  return arrayParserLoop(arrayParserState, x, parser, typarray);
};
function arrayParserLoop(s, x, parser, typarray) {
  const xs = [];
  const delimiter = typarray === 1020 ? ";" : ",";
  for (;s.i < x.length; s.i++) {
    s.char = x[s.i];
    if (s.quoted) {
      if (s.char === "\\") {
        s.str += x[++s.i];
      } else if (s.char === '"') {
        xs.push(parser ? parser(s.str) : s.str);
        s.str = "";
        s.quoted = x[s.i + 1] === '"';
        s.last = s.i + 2;
      } else {
        s.str += s.char;
      }
    } else if (s.char === '"') {
      s.quoted = true;
    } else if (s.char === "{") {
      s.last = ++s.i;
      xs.push(arrayParserLoop(s, x, parser, typarray));
    } else if (s.char === "}") {
      s.quoted = false;
      s.last < s.i && xs.push(parser ? parser(x.slice(s.last, s.i)) : x.slice(s.last, s.i));
      s.last = s.i + 1;
      break;
    } else if (s.char === delimiter && s.p !== "}" && s.p !== '"') {
      xs.push(parser ? parser(x.slice(s.last, s.i)) : x.slice(s.last, s.i));
      s.last = s.i + 1;
    }
    s.p = s.char;
  }
  s.last < s.i && xs.push(parser ? parser(x.slice(s.last, s.i + 1)) : x.slice(s.last, s.i + 1));
  return xs;
}
var toCamel = (x) => {
  let str = x[0];
  for (let i = 1;i < x.length; i++)
    str += x[i] === "_" ? x[++i].toUpperCase() : x[i];
  return str;
};
var toPascal = (x) => {
  let str = x[0].toUpperCase();
  for (let i = 1;i < x.length; i++)
    str += x[i] === "_" ? x[++i].toUpperCase() : x[i];
  return str;
};
var toKebab = (x) => x.replace(/_/g, "-");
var fromCamel = (x) => x.replace(/([A-Z])/g, "_$1").toLowerCase();
var fromPascal = (x) => (x.slice(0, 1) + x.slice(1).replace(/([A-Z])/g, "_$1")).toLowerCase();
var fromKebab = (x) => x.replace(/-/g, "_");
function createJsonTransform(fn) {
  return function jsonTransform(x, column) {
    return typeof x === "object" && x !== null && (column.type === 114 || column.type === 3802) ? Array.isArray(x) ? x.map((x2) => jsonTransform(x2, column)) : Object.entries(x).reduce((acc, [k, v]) => Object.assign(acc, { [fn(k)]: jsonTransform(v, column) }), {}) : x;
  };
}
toCamel.column = { from: toCamel };
toCamel.value = { from: createJsonTransform(toCamel) };
fromCamel.column = { to: fromCamel };
var camel = { ...toCamel };
camel.column.to = fromCamel;
toPascal.column = { from: toPascal };
toPascal.value = { from: createJsonTransform(toPascal) };
fromPascal.column = { to: fromPascal };
var pascal = { ...toPascal };
pascal.column.to = fromPascal;
toKebab.column = { from: toKebab };
toKebab.value = { from: createJsonTransform(toKebab) };
fromKebab.column = { to: fromKebab };
var kebab = { ...toKebab };
kebab.column.to = fromKebab;

// node_modules/postgres/src/connection.js
import net from "net";
import tls from "tls";
import crypto2 from "crypto";
import Stream from "stream";
import { performance } from "perf_hooks";

// node_modules/postgres/src/result.js
class Result extends Array {
  constructor() {
    super();
    Object.defineProperties(this, {
      count: { value: null, writable: true },
      state: { value: null, writable: true },
      command: { value: null, writable: true },
      columns: { value: null, writable: true },
      statement: { value: null, writable: true }
    });
  }
  static get [Symbol.species]() {
    return Array;
  }
}

// node_modules/postgres/src/queue.js
var queue_default = Queue;
function Queue(initial = []) {
  let xs = initial.slice();
  let index = 0;
  return {
    get length() {
      return xs.length - index;
    },
    remove: (x) => {
      const index2 = xs.indexOf(x);
      return index2 === -1 ? null : (xs.splice(index2, 1), x);
    },
    push: (x) => (xs.push(x), x),
    shift: () => {
      const out = xs[index++];
      if (index === xs.length) {
        index = 0;
        xs = [];
      } else {
        xs[index - 1] = undefined;
      }
      return out;
    }
  };
}

// node_modules/postgres/src/bytes.js
var size = 256;
var buffer = Buffer.allocUnsafe(size);
var messages = "BCcDdEFfHPpQSX".split("").reduce((acc, x) => {
  const v = x.charCodeAt(0);
  acc[x] = () => {
    buffer[0] = v;
    b.i = 5;
    return b;
  };
  return acc;
}, {});
var b = Object.assign(reset, messages, {
  N: String.fromCharCode(0),
  i: 0,
  inc(x) {
    b.i += x;
    return b;
  },
  str(x) {
    const length = Buffer.byteLength(x);
    fit(length);
    b.i += buffer.write(x, b.i, length, "utf8");
    return b;
  },
  i16(x) {
    fit(2);
    buffer.writeUInt16BE(x, b.i);
    b.i += 2;
    return b;
  },
  i32(x, i) {
    if (i || i === 0) {
      buffer.writeUInt32BE(x, i);
      return b;
    }
    fit(4);
    buffer.writeUInt32BE(x, b.i);
    b.i += 4;
    return b;
  },
  z(x) {
    fit(x);
    buffer.fill(0, b.i, b.i + x);
    b.i += x;
    return b;
  },
  raw(x) {
    buffer = Buffer.concat([buffer.subarray(0, b.i), x]);
    b.i = buffer.length;
    return b;
  },
  end(at = 1) {
    buffer.writeUInt32BE(b.i - at, at);
    const out = buffer.subarray(0, b.i);
    b.i = 0;
    buffer = Buffer.allocUnsafe(size);
    return out;
  }
});
var bytes_default = b;
function fit(x) {
  if (buffer.length - b.i < x) {
    const prev = buffer, length = prev.length;
    buffer = Buffer.allocUnsafe(length + (length >> 1) + x);
    prev.copy(buffer);
  }
}
function reset() {
  b.i = 0;
  return b;
}

// node_modules/postgres/src/connection.js
var connection_default = Connection;
var uid = 1;
var Sync = bytes_default().S().end();
var Flush = bytes_default().H().end();
var SSLRequest = bytes_default().i32(8).i32(80877103).end(8);
var ExecuteUnnamed = Buffer.concat([bytes_default().E().str(bytes_default.N).i32(0).end(), Sync]);
var DescribeUnnamed = bytes_default().D().str("S").str(bytes_default.N).end();
var noop = () => {};
var retryRoutines = new Set([
  "FetchPreparedStatement",
  "RevalidateCachedQuery",
  "transformAssignedExpr"
]);
var errorFields = {
  83: "severity_local",
  86: "severity",
  67: "code",
  77: "message",
  68: "detail",
  72: "hint",
  80: "position",
  112: "internal_position",
  113: "internal_query",
  87: "where",
  115: "schema_name",
  116: "table_name",
  99: "column_name",
  100: "data type_name",
  110: "constraint_name",
  70: "file",
  76: "line",
  82: "routine"
};
function Connection(options, queues = {}, { onopen = noop, onend = noop, onclose = noop } = {}) {
  const {
    sslnegotiation,
    ssl,
    max,
    user,
    host,
    port,
    database,
    parsers: parsers2,
    transform,
    onnotice,
    onnotify,
    onparameter,
    max_pipeline,
    keep_alive,
    backoff,
    target_session_attrs
  } = options;
  const sent = queue_default(), id = uid++, backend = { pid: null, secret: null }, idleTimer = timer(end, options.idle_timeout), lifeTimer = timer(end, options.max_lifetime), connectTimer = timer(connectTimedOut, options.connect_timeout);
  let socket = null, cancelMessage, errorResponse = null, result = new Result, incoming = Buffer.alloc(0), needsTypes = options.fetch_types, backendParameters = {}, statements = {}, statementId = Math.random().toString(36).slice(2), statementCount = 1, closedTime = 0, remaining = 0, hostIndex = 0, retries = 0, length = 0, delay = 0, rows = 0, serverSignature = null, nextWriteTimer = null, terminated = false, incomings = null, results = null, initial = null, ending = null, stream = null, chunk = null, ended = null, nonce = null, query = null, final = null;
  const connection2 = {
    queue: queues.closed,
    idleTimer,
    connect(query2) {
      initial = query2;
      reconnect();
    },
    terminate,
    execute,
    cancel,
    end,
    count: 0,
    id
  };
  queues.closed && queues.closed.push(connection2);
  return connection2;
  async function createSocket() {
    let x;
    try {
      x = options.socket ? await Promise.resolve(options.socket(options)) : new net.Socket;
    } catch (e) {
      error(e);
      return;
    }
    x.on("error", error);
    x.on("close", closed);
    x.on("drain", drain);
    return x;
  }
  async function cancel({ pid, secret }, resolve, reject) {
    try {
      cancelMessage = bytes_default().i32(16).i32(80877102).i32(pid).i32(secret).end(16);
      await connect();
      socket.once("error", reject);
      socket.once("close", resolve);
    } catch (error2) {
      reject(error2);
    }
  }
  function execute(q) {
    if (terminated)
      return queryError(q, Errors.connection("CONNECTION_DESTROYED", options));
    if (stream)
      return queryError(q, Errors.generic("COPY_IN_PROGRESS", "You cannot execute queries during copy"));
    if (q.cancelled)
      return;
    try {
      q.state = backend;
      query ? sent.push(q) : (query = q, query.active = true);
      build(q);
      return write(toBuffer(q)) && !q.describeFirst && !q.cursorFn && sent.length < max_pipeline && (!q.options.onexecute || q.options.onexecute(connection2));
    } catch (error2) {
      sent.length === 0 && write(Sync);
      errored(error2);
      return true;
    }
  }
  function toBuffer(q) {
    if (q.parameters.length >= 65534)
      throw Errors.generic("MAX_PARAMETERS_EXCEEDED", "Max number of parameters (65534) exceeded");
    return q.options.simple ? bytes_default().Q().str(q.statement.string + bytes_default.N).end() : q.describeFirst ? Buffer.concat([describe(q), Flush]) : q.prepare ? q.prepared ? prepared(q) : Buffer.concat([describe(q), prepared(q)]) : unnamed(q);
  }
  function describe(q) {
    return Buffer.concat([
      Parse(q.statement.string, q.parameters, q.statement.types, q.statement.name),
      Describe("S", q.statement.name)
    ]);
  }
  function prepared(q) {
    return Buffer.concat([
      Bind(q.parameters, q.statement.types, q.statement.name, q.cursorName),
      q.cursorFn ? Execute("", q.cursorRows) : ExecuteUnnamed
    ]);
  }
  function unnamed(q) {
    return Buffer.concat([
      Parse(q.statement.string, q.parameters, q.statement.types),
      DescribeUnnamed,
      prepared(q)
    ]);
  }
  function build(q) {
    const parameters = [], types2 = [];
    const string = stringify(q, q.strings[0], q.args[0], parameters, types2, options);
    !q.tagged && q.args.forEach((x) => handleValue(x, parameters, types2, options));
    q.prepare = options.prepare && ("prepare" in q.options ? q.options.prepare : true);
    q.string = string;
    q.signature = q.prepare && types2 + string;
    q.onlyDescribe && delete statements[q.signature];
    q.parameters = q.parameters || parameters;
    q.prepared = q.prepare && q.signature in statements;
    q.describeFirst = q.onlyDescribe || parameters.length && !q.prepared;
    q.statement = q.prepared ? statements[q.signature] : { string, types: types2, name: q.prepare ? statementId + statementCount++ : "" };
    typeof options.debug === "function" && options.debug(id, string, parameters, types2);
  }
  function write(x, fn) {
    chunk = chunk ? Buffer.concat([chunk, x]) : Buffer.from(x);
    if (fn || chunk.length >= 1024)
      return nextWrite(fn);
    nextWriteTimer === null && (nextWriteTimer = setImmediate(nextWrite));
    return true;
  }
  function nextWrite(fn) {
    const x = socket.write(chunk, fn);
    nextWriteTimer !== null && clearImmediate(nextWriteTimer);
    chunk = nextWriteTimer = null;
    return x;
  }
  function connectTimedOut() {
    errored(Errors.connection("CONNECT_TIMEOUT", options, socket));
    socket.destroy();
  }
  async function secure() {
    if (sslnegotiation !== "direct") {
      write(SSLRequest);
      const canSSL = await new Promise((r) => socket.once("data", (x) => r(x[0] === 83)));
      if (!canSSL && ssl === "prefer")
        return connected();
    }
    const options2 = {
      socket,
      servername: net.isIP(socket.host) ? undefined : socket.host
    };
    if (sslnegotiation === "direct")
      options2.ALPNProtocols = ["postgresql"];
    if (ssl === "require" || ssl === "allow" || ssl === "prefer")
      options2.rejectUnauthorized = false;
    else if (typeof ssl === "object")
      Object.assign(options2, ssl);
    socket.removeAllListeners();
    socket = tls.connect(options2);
    socket.on("secureConnect", connected);
    socket.on("error", error);
    socket.on("close", closed);
    socket.on("drain", drain);
  }
  function drain() {
    !query && onopen(connection2);
  }
  function data(x) {
    if (incomings) {
      incomings.push(x);
      remaining -= x.length;
      if (remaining > 0)
        return;
    }
    incoming = incomings ? Buffer.concat(incomings, length - remaining) : incoming.length === 0 ? x : Buffer.concat([incoming, x], incoming.length + x.length);
    while (incoming.length > 4) {
      length = incoming.readUInt32BE(1);
      if (length >= incoming.length) {
        remaining = length - incoming.length;
        incomings = [incoming];
        break;
      }
      try {
        handle(incoming.subarray(0, length + 1));
      } catch (e) {
        query && (query.cursorFn || query.describeFirst) && write(Sync);
        errored(e);
      }
      incoming = incoming.subarray(length + 1);
      remaining = 0;
      incomings = null;
    }
  }
  async function connect() {
    terminated = false;
    backendParameters = {};
    socket || (socket = await createSocket());
    if (!socket)
      return;
    connectTimer.start();
    if (options.socket)
      return ssl ? secure() : connected();
    socket.on("connect", ssl ? secure : connected);
    if (options.path)
      return socket.connect(options.path);
    socket.ssl = ssl;
    socket.connect(port[hostIndex], host[hostIndex]);
    socket.host = host[hostIndex];
    socket.port = port[hostIndex];
    hostIndex = (hostIndex + 1) % port.length;
  }
  function reconnect() {
    setTimeout(connect, closedTime ? Math.max(0, closedTime + delay - performance.now()) : 0);
  }
  function connected() {
    try {
      statements = {};
      needsTypes = options.fetch_types;
      statementId = Math.random().toString(36).slice(2);
      statementCount = 1;
      lifeTimer.start();
      socket.on("data", data);
      keep_alive && socket.setKeepAlive && socket.setKeepAlive(true, 1000 * keep_alive);
      const s = StartupMessage();
      write(s);
    } catch (err) {
      error(err);
    }
  }
  function error(err) {
    if (connection2.queue === queues.connecting && options.host[retries + 1])
      return;
    errored(err);
    while (sent.length)
      queryError(sent.shift(), err);
  }
  function errored(err) {
    stream && (stream.destroy(err), stream = null);
    query && queryError(query, err);
    initial && (queryError(initial, err), initial = null);
  }
  function queryError(query2, err) {
    if (query2.reserve)
      return query2.reject(err);
    if (!err || typeof err !== "object")
      err = new Error(err);
    "query" in err || "parameters" in err || Object.defineProperties(err, {
      stack: { value: err.stack + query2.origin.replace(/.*\n/, `
`), enumerable: options.debug },
      query: { value: query2.string, enumerable: options.debug },
      parameters: { value: query2.parameters, enumerable: options.debug },
      args: { value: query2.args, enumerable: options.debug },
      types: { value: query2.statement && query2.statement.types, enumerable: options.debug }
    });
    query2.reject(err);
  }
  function end() {
    return ending || (!connection2.reserved && onend(connection2), !connection2.reserved && !initial && !query && sent.length === 0 ? (terminate(), new Promise((r) => socket && socket.readyState !== "closed" ? socket.once("close", r) : r())) : ending = new Promise((r) => ended = r));
  }
  function terminate() {
    terminated = true;
    if (stream || query || initial || sent.length)
      error(Errors.connection("CONNECTION_DESTROYED", options));
    clearImmediate(nextWriteTimer);
    if (socket) {
      socket.removeListener("data", data);
      socket.removeListener("connect", connected);
      socket.readyState === "open" && socket.end(bytes_default().X().end());
    }
    ended && (ended(), ending = ended = null);
  }
  async function closed(hadError) {
    incoming = Buffer.alloc(0);
    remaining = 0;
    incomings = null;
    clearImmediate(nextWriteTimer);
    socket.removeListener("data", data);
    socket.removeListener("connect", connected);
    idleTimer.cancel();
    lifeTimer.cancel();
    connectTimer.cancel();
    socket.removeAllListeners();
    socket = null;
    if (initial)
      return reconnect();
    !hadError && (query || sent.length) && error(Errors.connection("CONNECTION_CLOSED", options, socket));
    closedTime = performance.now();
    hadError && options.shared.retries++;
    delay = (typeof backoff === "function" ? backoff(options.shared.retries) : backoff) * 1000;
    onclose(connection2, Errors.connection("CONNECTION_CLOSED", options, socket));
  }
  function handle(xs, x = xs[0]) {
    (x === 68 ? DataRow : x === 100 ? CopyData : x === 65 ? NotificationResponse : x === 83 ? ParameterStatus : x === 90 ? ReadyForQuery : x === 67 ? CommandComplete : x === 50 ? BindComplete : x === 49 ? ParseComplete : x === 116 ? ParameterDescription : x === 84 ? RowDescription : x === 82 ? Authentication : x === 110 ? NoData : x === 75 ? BackendKeyData : x === 69 ? ErrorResponse : x === 115 ? PortalSuspended : x === 51 ? CloseComplete : x === 71 ? CopyInResponse : x === 78 ? NoticeResponse : x === 72 ? CopyOutResponse : x === 99 ? CopyDone : x === 73 ? EmptyQueryResponse : x === 86 ? FunctionCallResponse : x === 118 ? NegotiateProtocolVersion : x === 87 ? CopyBothResponse : UnknownMessage)(xs);
  }
  function DataRow(x) {
    let index = 7;
    let length2;
    let column;
    let value;
    const row = query.isRaw ? new Array(query.statement.columns.length) : {};
    for (let i = 0;i < query.statement.columns.length; i++) {
      column = query.statement.columns[i];
      length2 = x.readInt32BE(index);
      index += 4;
      value = length2 === -1 ? null : query.isRaw === true ? x.subarray(index, index += length2) : column.parser === undefined ? x.toString("utf8", index, index += length2) : column.parser.array === true ? column.parser(x.toString("utf8", index + 1, index += length2)) : column.parser(x.toString("utf8", index, index += length2));
      query.isRaw ? row[i] = query.isRaw === true ? value : transform.value.from ? transform.value.from(value, column) : value : row[column.name] = transform.value.from ? transform.value.from(value, column) : value;
    }
    query.forEachFn ? query.forEachFn(transform.row.from ? transform.row.from(row) : row, result) : result[rows++] = transform.row.from ? transform.row.from(row) : row;
  }
  function ParameterStatus(x) {
    const [k, v] = x.toString("utf8", 5, x.length - 1).split(bytes_default.N);
    backendParameters[k] = v;
    if (options.parameters[k] !== v) {
      options.parameters[k] = v;
      onparameter && onparameter(k, v);
    }
  }
  function ReadyForQuery(x) {
    if (query) {
      if (errorResponse) {
        query.retried ? errored(query.retried) : query.prepared && retryRoutines.has(errorResponse.routine) ? retry(query, errorResponse) : errored(errorResponse);
      } else {
        query.resolve(results || result);
      }
    } else if (errorResponse) {
      errored(errorResponse);
    }
    query = results = errorResponse = null;
    result = new Result;
    connectTimer.cancel();
    if (initial) {
      if (target_session_attrs) {
        if (!backendParameters.in_hot_standby || !backendParameters.default_transaction_read_only)
          return fetchState();
        else if (tryNext(target_session_attrs, backendParameters))
          return terminate();
      }
      if (needsTypes) {
        initial.reserve && (initial = null);
        return fetchArrayTypes();
      }
      initial && !initial.reserve && execute(initial);
      options.shared.retries = retries = 0;
      initial = null;
      return;
    }
    while (sent.length && (query = sent.shift()) && (query.active = true, query.cancelled))
      Connection(options).cancel(query.state, query.cancelled.resolve, query.cancelled.reject);
    if (query)
      return;
    connection2.reserved ? !connection2.reserved.release && x[5] === 73 ? ending ? terminate() : (connection2.reserved = null, onopen(connection2)) : connection2.reserved() : ending ? terminate() : onopen(connection2);
  }
  function CommandComplete(x) {
    rows = 0;
    for (let i = x.length - 1;i > 0; i--) {
      if (x[i] === 32 && x[i + 1] < 58 && result.count === null)
        result.count = +x.toString("utf8", i + 1, x.length - 1);
      if (x[i - 1] >= 65) {
        result.command = x.toString("utf8", 5, i);
        result.state = backend;
        break;
      }
    }
    final && (final(), final = null);
    if (result.command === "BEGIN" && max !== 1 && !connection2.reserved)
      return errored(Errors.generic("UNSAFE_TRANSACTION", "Only use sql.begin, sql.reserved or max: 1"));
    if (query.options.simple)
      return BindComplete();
    if (query.cursorFn) {
      result.count && query.cursorFn(result);
      write(Sync);
    }
  }
  function ParseComplete() {
    query.parsing = false;
  }
  function BindComplete() {
    !result.statement && (result.statement = query.statement);
    result.columns = query.statement.columns;
  }
  function ParameterDescription(x) {
    const length2 = x.readUInt16BE(5);
    for (let i = 0;i < length2; ++i)
      !query.statement.types[i] && (query.statement.types[i] = x.readUInt32BE(7 + i * 4));
    query.prepare && (statements[query.signature] = query.statement);
    query.describeFirst && !query.onlyDescribe && (write(prepared(query)), query.describeFirst = false);
  }
  function RowDescription(x) {
    if (result.command) {
      results = results || [result];
      results.push(result = new Result);
      result.count = null;
      query.statement.columns = null;
    }
    const length2 = x.readUInt16BE(5);
    let index = 7;
    let start;
    query.statement.columns = Array(length2);
    for (let i = 0;i < length2; ++i) {
      start = index;
      while (x[index++] !== 0)
        ;
      const table = x.readUInt32BE(index);
      const number = x.readUInt16BE(index + 4);
      const type = x.readUInt32BE(index + 6);
      query.statement.columns[i] = {
        name: transform.column.from ? transform.column.from(x.toString("utf8", start, index - 1)) : x.toString("utf8", start, index - 1),
        parser: parsers2[type],
        table,
        number,
        type
      };
      index += 18;
    }
    result.statement = query.statement;
    if (query.onlyDescribe)
      return query.resolve(query.statement), write(Sync);
  }
  async function Authentication(x, type = x.readUInt32BE(5)) {
    (type === 3 ? AuthenticationCleartextPassword : type === 5 ? AuthenticationMD5Password : type === 10 ? SASL : type === 11 ? SASLContinue : type === 12 ? SASLFinal : type !== 0 ? UnknownAuth : noop)(x, type);
  }
  async function AuthenticationCleartextPassword() {
    const payload = await Pass();
    write(bytes_default().p().str(payload).z(1).end());
  }
  async function AuthenticationMD5Password(x) {
    const payload = "md5" + await md5(Buffer.concat([
      Buffer.from(await md5(await Pass() + user)),
      x.subarray(9)
    ]));
    write(bytes_default().p().str(payload).z(1).end());
  }
  async function SASL() {
    nonce = (await crypto2.randomBytes(18)).toString("base64");
    bytes_default().p().str("SCRAM-SHA-256" + bytes_default.N);
    const i = bytes_default.i;
    write(bytes_default.inc(4).str("n,,n=*,r=" + nonce).i32(bytes_default.i - i - 4, i).end());
  }
  async function SASLContinue(x) {
    const res = x.toString("utf8", 9).split(",").reduce((acc, x2) => (acc[x2[0]] = x2.slice(2), acc), {});
    const saltedPassword = await crypto2.pbkdf2Sync(await Pass(), Buffer.from(res.s, "base64"), parseInt(res.i), 32, "sha256");
    const clientKey = await hmac(saltedPassword, "Client Key");
    const auth = "n=*,r=" + nonce + "," + "r=" + res.r + ",s=" + res.s + ",i=" + res.i + ",c=biws,r=" + res.r;
    serverSignature = (await hmac(await hmac(saltedPassword, "Server Key"), auth)).toString("base64");
    const payload = "c=biws,r=" + res.r + ",p=" + xor(clientKey, Buffer.from(await hmac(await sha256(clientKey), auth))).toString("base64");
    write(bytes_default().p().str(payload).end());
  }
  function SASLFinal(x) {
    if (x.toString("utf8", 9).split(bytes_default.N, 1)[0].slice(2) === serverSignature)
      return;
    errored(Errors.generic("SASL_SIGNATURE_MISMATCH", "The server did not return the correct signature"));
    socket.destroy();
  }
  function Pass() {
    return Promise.resolve(typeof options.pass === "function" ? options.pass() : options.pass);
  }
  function NoData() {
    result.statement = query.statement;
    result.statement.columns = [];
    if (query.onlyDescribe)
      return query.resolve(query.statement), write(Sync);
  }
  function BackendKeyData(x) {
    backend.pid = x.readUInt32BE(5);
    backend.secret = x.readUInt32BE(9);
  }
  async function fetchArrayTypes() {
    needsTypes = false;
    const types2 = await new Query([`
      select b.oid, b.typarray
      from pg_catalog.pg_type a
      left join pg_catalog.pg_type b on b.oid = a.typelem
      where a.typcategory = 'A'
      group by b.oid, b.typarray
      order by b.oid
    `], [], execute);
    types2.forEach(({ oid, typarray }) => addArrayType(oid, typarray));
  }
  function addArrayType(oid, typarray) {
    if (!!options.parsers[typarray] && !!options.serializers[typarray])
      return;
    const parser = options.parsers[oid];
    options.shared.typeArrayMap[oid] = typarray;
    options.parsers[typarray] = (xs) => arrayParser(xs, parser, typarray);
    options.parsers[typarray].array = true;
    options.serializers[typarray] = (xs) => arraySerializer(xs, options.serializers[oid], options, typarray);
  }
  function tryNext(x, xs) {
    return x === "read-write" && xs.default_transaction_read_only === "on" || x === "read-only" && xs.default_transaction_read_only === "off" || x === "primary" && xs.in_hot_standby === "on" || x === "standby" && xs.in_hot_standby === "off" || x === "prefer-standby" && xs.in_hot_standby === "off" && options.host[retries];
  }
  function fetchState() {
    const query2 = new Query([`
      show transaction_read_only;
      select pg_catalog.pg_is_in_recovery()
    `], [], execute, null, { simple: true });
    query2.resolve = ([[a], [b2]]) => {
      backendParameters.default_transaction_read_only = a.transaction_read_only;
      backendParameters.in_hot_standby = b2.pg_is_in_recovery ? "on" : "off";
    };
    query2.execute();
  }
  function ErrorResponse(x) {
    if (query) {
      (query.cursorFn || query.describeFirst) && write(Sync);
      errorResponse = Errors.postgres(parseError(x));
    } else {
      errored(Errors.postgres(parseError(x)));
    }
  }
  function retry(q, error2) {
    delete statements[q.signature];
    q.retried = error2;
    execute(q);
  }
  function NotificationResponse(x) {
    if (!onnotify)
      return;
    let index = 9;
    while (x[index++] !== 0)
      ;
    onnotify(x.toString("utf8", 9, index - 1), x.toString("utf8", index, x.length - 1));
  }
  async function PortalSuspended() {
    try {
      const x = await Promise.resolve(query.cursorFn(result));
      rows = 0;
      x === CLOSE ? write(Close(query.portal)) : (result = new Result, write(Execute("", query.cursorRows)));
    } catch (err) {
      write(Sync);
      query.reject(err);
    }
  }
  function CloseComplete() {
    result.count && query.cursorFn(result);
    query.resolve(result);
  }
  function CopyInResponse() {
    stream = new Stream.Writable({
      autoDestroy: true,
      write(chunk2, encoding, callback) {
        socket.write(bytes_default().d().raw(chunk2).end(), callback);
      },
      destroy(error2, callback) {
        callback(error2);
        socket.write(bytes_default().f().str(error2 + bytes_default.N).end());
        stream = null;
      },
      final(callback) {
        socket.write(bytes_default().c().end());
        final = callback;
        stream = null;
      }
    });
    query.resolve(stream);
  }
  function CopyOutResponse() {
    stream = new Stream.Readable({
      read() {
        socket.resume();
      }
    });
    query.resolve(stream);
  }
  function CopyBothResponse() {
    stream = new Stream.Duplex({
      autoDestroy: true,
      read() {
        socket.resume();
      },
      write(chunk2, encoding, callback) {
        socket.write(bytes_default().d().raw(chunk2).end(), callback);
      },
      destroy(error2, callback) {
        callback(error2);
        socket.write(bytes_default().f().str(error2 + bytes_default.N).end());
        stream = null;
      },
      final(callback) {
        socket.write(bytes_default().c().end());
        final = callback;
      }
    });
    query.resolve(stream);
  }
  function CopyData(x) {
    stream && (stream.push(x.subarray(5)) || socket.pause());
  }
  function CopyDone() {
    stream && stream.push(null);
    stream = null;
  }
  function NoticeResponse(x) {
    onnotice ? onnotice(parseError(x)) : console.log(parseError(x));
  }
  function EmptyQueryResponse() {}
  function FunctionCallResponse() {
    errored(Errors.notSupported("FunctionCallResponse"));
  }
  function NegotiateProtocolVersion() {
    errored(Errors.notSupported("NegotiateProtocolVersion"));
  }
  function UnknownMessage(x) {
    console.error("Postgres.js : Unknown Message:", x[0]);
  }
  function UnknownAuth(x, type) {
    console.error("Postgres.js : Unknown Auth:", type);
  }
  function Bind(parameters, types2, statement = "", portal = "") {
    let prev, type;
    bytes_default().B().str(portal + bytes_default.N).str(statement + bytes_default.N).i16(0).i16(parameters.length);
    parameters.forEach((x, i) => {
      if (x === null)
        return bytes_default.i32(4294967295);
      type = types2[i];
      parameters[i] = x = type in options.serializers ? options.serializers[type](x) : "" + x;
      prev = bytes_default.i;
      bytes_default.inc(4).str(x).i32(bytes_default.i - prev - 4, prev);
    });
    bytes_default.i16(0);
    return bytes_default.end();
  }
  function Parse(str, parameters, types2, name = "") {
    bytes_default().P().str(name + bytes_default.N).str(str + bytes_default.N).i16(parameters.length);
    parameters.forEach((x, i) => bytes_default.i32(types2[i] || 0));
    return bytes_default.end();
  }
  function Describe(x, name = "") {
    return bytes_default().D().str(x).str(name + bytes_default.N).end();
  }
  function Execute(portal = "", rows2 = 0) {
    return Buffer.concat([
      bytes_default().E().str(portal + bytes_default.N).i32(rows2).end(),
      Flush
    ]);
  }
  function Close(portal = "") {
    return Buffer.concat([
      bytes_default().C().str("P").str(portal + bytes_default.N).end(),
      bytes_default().S().end()
    ]);
  }
  function StartupMessage() {
    return cancelMessage || bytes_default().inc(4).i16(3).z(2).str(Object.entries(Object.assign({
      user,
      database,
      client_encoding: "UTF8"
    }, options.connection)).filter(([, v]) => v).map(([k, v]) => k + bytes_default.N + v).join(bytes_default.N)).z(2).end(0);
  }
}
function parseError(x) {
  const error = {};
  let start = 5;
  for (let i = 5;i < x.length - 1; i++) {
    if (x[i] === 0) {
      error[errorFields[x[start]]] = x.toString("utf8", start + 1, i);
      start = i + 1;
    }
  }
  return error;
}
function md5(x) {
  return crypto2.createHash("md5").update(x).digest("hex");
}
function hmac(key, x) {
  return crypto2.createHmac("sha256", key).update(x).digest();
}
function sha256(x) {
  return crypto2.createHash("sha256").update(x).digest();
}
function xor(a, b2) {
  const length = Math.max(a.length, b2.length);
  const buffer2 = Buffer.allocUnsafe(length);
  for (let i = 0;i < length; i++)
    buffer2[i] = a[i] ^ b2[i];
  return buffer2;
}
function timer(fn, seconds) {
  seconds = typeof seconds === "function" ? seconds() : seconds;
  if (!seconds)
    return { cancel: noop, start: noop };
  let timer2;
  return {
    cancel() {
      timer2 && (clearTimeout(timer2), timer2 = null);
    },
    start() {
      timer2 && clearTimeout(timer2);
      timer2 = setTimeout(done, seconds * 1000, arguments);
    }
  };
  function done(args) {
    fn.apply(null, args);
    timer2 = null;
  }
}

// node_modules/postgres/src/subscribe.js
var noop2 = () => {};
function Subscribe(postgres2, options) {
  const subscribers = new Map, slot = "postgresjs_" + Math.random().toString(36).slice(2), state = {};
  let connection2, stream, ended = false;
  const sql = subscribe.sql = postgres2({
    ...options,
    transform: { column: {}, value: {}, row: {} },
    max: 1,
    fetch_types: false,
    idle_timeout: null,
    max_lifetime: null,
    connection: {
      ...options.connection,
      replication: "database"
    },
    onclose: async function() {
      if (ended)
        return;
      stream = null;
      state.pid = state.secret = undefined;
      connected(await init(sql, slot, options.publications));
      subscribers.forEach((event) => event.forEach(({ onsubscribe }) => onsubscribe()));
    },
    no_subscribe: true
  });
  const { end, close } = sql;
  sql.end = async () => {
    ended = true;
    stream && await new Promise((r) => (stream.once("close", r), stream.end()));
    return end();
  };
  sql.close = async () => {
    stream && await new Promise((r) => (stream.once("close", r), stream.end()));
    return close();
  };
  return subscribe;
  async function subscribe(event, fn, onsubscribe = noop2, onerror = noop2) {
    event = parseEvent(event);
    if (!connection2)
      connection2 = init(sql, slot, options.publications);
    const subscriber = { fn, onsubscribe };
    const fns = subscribers.has(event) ? subscribers.get(event).add(subscriber) : subscribers.set(event, new Set([subscriber])).get(event);
    const unsubscribe = () => {
      fns.delete(subscriber);
      fns.size === 0 && subscribers.delete(event);
    };
    return connection2.then((x) => {
      connected(x);
      onsubscribe();
      stream && stream.on("error", onerror);
      return { unsubscribe, state, sql };
    });
  }
  function connected(x) {
    stream = x.stream;
    state.pid = x.state.pid;
    state.secret = x.state.secret;
  }
  async function init(sql2, slot2, publications) {
    if (!publications)
      throw new Error("Missing publication names");
    const xs = await sql2.unsafe(`CREATE_REPLICATION_SLOT ${slot2} TEMPORARY LOGICAL pgoutput NOEXPORT_SNAPSHOT`);
    const [x] = xs;
    const stream2 = await sql2.unsafe(`START_REPLICATION SLOT ${slot2} LOGICAL ${x.consistent_point} (proto_version '1', publication_names '${publications}')`).writable();
    const state2 = {
      lsn: Buffer.concat(x.consistent_point.split("/").map((x2) => Buffer.from(("00000000" + x2).slice(-8), "hex")))
    };
    stream2.on("data", data);
    stream2.on("error", error);
    stream2.on("close", sql2.close);
    return { stream: stream2, state: xs.state };
    function error(e) {
      console.error("Unexpected error during logical streaming - reconnecting", e);
    }
    function data(x2) {
      if (x2[0] === 119) {
        parse(x2.subarray(25), state2, sql2.options.parsers, handle, options.transform);
      } else if (x2[0] === 107 && x2[17]) {
        state2.lsn = x2.subarray(1, 9);
        pong();
      }
    }
    function handle(a, b2) {
      const path = b2.relation.schema + "." + b2.relation.table;
      call("*", a, b2);
      call("*:" + path, a, b2);
      b2.relation.keys.length && call("*:" + path + "=" + b2.relation.keys.map((x2) => a[x2.name]), a, b2);
      call(b2.command, a, b2);
      call(b2.command + ":" + path, a, b2);
      b2.relation.keys.length && call(b2.command + ":" + path + "=" + b2.relation.keys.map((x2) => a[x2.name]), a, b2);
    }
    function pong() {
      const x2 = Buffer.alloc(34);
      x2[0] = 114;
      x2.fill(state2.lsn, 1);
      x2.writeBigInt64BE(BigInt(Date.now() - Date.UTC(2000, 0, 1)) * BigInt(1000), 25);
      stream2.write(x2);
    }
  }
  function call(x, a, b2) {
    subscribers.has(x) && subscribers.get(x).forEach(({ fn }) => fn(a, b2, x));
  }
}
function Time(x) {
  return new Date(Date.UTC(2000, 0, 1) + Number(x / BigInt(1000)));
}
function parse(x, state, parsers2, handle, transform) {
  const char = (acc, [k, v]) => (acc[k.charCodeAt(0)] = v, acc);
  Object.entries({
    R: (x2) => {
      let i = 1;
      const r = state[x2.readUInt32BE(i)] = {
        schema: x2.toString("utf8", i += 4, i = x2.indexOf(0, i)) || "pg_catalog",
        table: x2.toString("utf8", i + 1, i = x2.indexOf(0, i + 1)),
        columns: Array(x2.readUInt16BE(i += 2)),
        keys: []
      };
      i += 2;
      let columnIndex = 0, column;
      while (i < x2.length) {
        column = r.columns[columnIndex++] = {
          key: x2[i++],
          name: transform.column.from ? transform.column.from(x2.toString("utf8", i, i = x2.indexOf(0, i))) : x2.toString("utf8", i, i = x2.indexOf(0, i)),
          type: x2.readUInt32BE(i += 1),
          parser: parsers2[x2.readUInt32BE(i)],
          atttypmod: x2.readUInt32BE(i += 4)
        };
        column.key && r.keys.push(column);
        i += 4;
      }
    },
    Y: () => {},
    O: () => {},
    B: (x2) => {
      state.date = Time(x2.readBigInt64BE(9));
      state.lsn = x2.subarray(1, 9);
    },
    I: (x2) => {
      let i = 1;
      const relation = state[x2.readUInt32BE(i)];
      const { row } = tuples(x2, relation.columns, i += 7, transform);
      handle(row, {
        command: "insert",
        relation
      });
    },
    D: (x2) => {
      let i = 1;
      const relation = state[x2.readUInt32BE(i)];
      i += 4;
      const key = x2[i] === 75;
      handle(key || x2[i] === 79 ? tuples(x2, relation.columns, i += 3, transform).row : null, {
        command: "delete",
        relation,
        key
      });
    },
    U: (x2) => {
      let i = 1;
      const relation = state[x2.readUInt32BE(i)];
      i += 4;
      const key = x2[i] === 75;
      const xs = key || x2[i] === 79 ? tuples(x2, relation.columns, i += 3, transform) : null;
      xs && (i = xs.i);
      const { row } = tuples(x2, relation.columns, i + 3, transform);
      handle(row, {
        command: "update",
        relation,
        key,
        old: xs && xs.row
      });
    },
    T: () => {},
    C: () => {}
  }).reduce(char, {})[x[0]](x);
}
function tuples(x, columns, xi, transform) {
  let type, column, value;
  const row = transform.raw ? new Array(columns.length) : {};
  for (let i = 0;i < columns.length; i++) {
    type = x[xi++];
    column = columns[i];
    value = type === 110 ? null : type === 117 ? undefined : column.parser === undefined ? x.toString("utf8", xi + 4, xi += 4 + x.readUInt32BE(xi)) : column.parser.array === true ? column.parser(x.toString("utf8", xi + 5, xi += 4 + x.readUInt32BE(xi))) : column.parser(x.toString("utf8", xi + 4, xi += 4 + x.readUInt32BE(xi)));
    transform.raw ? row[i] = transform.raw === true ? value : transform.value.from ? transform.value.from(value, column) : value : row[column.name] = transform.value.from ? transform.value.from(value, column) : value;
  }
  return { i: xi, row: transform.row.from ? transform.row.from(row) : row };
}
function parseEvent(x) {
  const xs = x.match(/^(\*|insert|update|delete)?:?([^.]+?\.?[^=]+)?=?(.+)?/i) || [];
  if (!xs)
    throw new Error("Malformed subscribe pattern: " + x);
  const [, command, path, key] = xs;
  return (command || "*") + (path ? ":" + (path.indexOf(".") === -1 ? "public." + path : path) : "") + (key ? "=" + key : "");
}

// node_modules/postgres/src/large.js
import Stream2 from "stream";
function largeObject(sql, oid, mode = 131072 | 262144) {
  return new Promise(async (resolve, reject) => {
    await sql.begin(async (sql2) => {
      let finish;
      !oid && ([{ oid }] = await sql2`select lo_creat(-1) as oid`);
      const [{ fd }] = await sql2`select lo_open(${oid}, ${mode}) as fd`;
      const lo = {
        writable,
        readable,
        close: () => sql2`select lo_close(${fd})`.then(finish),
        tell: () => sql2`select lo_tell64(${fd})`,
        read: (x) => sql2`select loread(${fd}, ${x}) as data`,
        write: (x) => sql2`select lowrite(${fd}, ${x})`,
        truncate: (x) => sql2`select lo_truncate64(${fd}, ${x})`,
        seek: (x, whence = 0) => sql2`select lo_lseek64(${fd}, ${x}, ${whence})`,
        size: () => sql2`
          select
            lo_lseek64(${fd}, location, 0) as position,
            seek.size
          from (
            select
              lo_lseek64($1, 0, 2) as size,
              tell.location
            from (select lo_tell64($1) as location) tell
          ) seek
        `
      };
      resolve(lo);
      return new Promise(async (r) => finish = r);
      async function readable({
        highWaterMark = 2048 * 8,
        start = 0,
        end = Infinity
      } = {}) {
        let max = end - start;
        start && await lo.seek(start);
        return new Stream2.Readable({
          highWaterMark,
          async read(size2) {
            const l = size2 > max ? size2 - max : size2;
            max -= size2;
            const [{ data }] = await lo.read(l);
            this.push(data);
            if (data.length < size2)
              this.push(null);
          }
        });
      }
      async function writable({
        highWaterMark = 2048 * 8,
        start = 0
      } = {}) {
        start && await lo.seek(start);
        return new Stream2.Writable({
          highWaterMark,
          write(chunk, encoding, callback) {
            lo.write(chunk).then(() => callback(), callback);
          }
        });
      }
    }).catch(reject);
  });
}

// node_modules/postgres/src/index.js
Object.assign(Postgres, {
  PostgresError,
  toPascal,
  pascal,
  toCamel,
  camel,
  toKebab,
  kebab,
  fromPascal,
  fromCamel,
  fromKebab,
  BigInt: {
    to: 20,
    from: [20],
    parse: (x) => BigInt(x),
    serialize: (x) => x.toString()
  }
});
var src_default = Postgres;
function Postgres(a, b2) {
  const options = parseOptions(a, b2), subscribe = options.no_subscribe || Subscribe(Postgres, { ...options });
  let ending = false;
  const queries = queue_default(), connecting = queue_default(), reserved = queue_default(), closed = queue_default(), ended = queue_default(), open = queue_default(), busy = queue_default(), full = queue_default(), queues = { connecting, reserved, closed, ended, open, busy, full };
  const connections = [...Array(options.max)].map(() => connection_default(options, queues, { onopen, onend, onclose }));
  const sql = Sql(handler);
  Object.assign(sql, {
    get parameters() {
      return options.parameters;
    },
    largeObject: largeObject.bind(null, sql),
    subscribe,
    CLOSE,
    END: CLOSE,
    PostgresError,
    options,
    reserve,
    listen,
    begin,
    close,
    end
  });
  return sql;
  function Sql(handler2) {
    handler2.debug = options.debug;
    Object.entries(options.types).reduce((acc, [name, type]) => {
      acc[name] = (x) => new Parameter(x, type.to);
      return acc;
    }, typed);
    Object.assign(sql2, {
      types: typed,
      typed,
      unsafe,
      notify,
      array,
      json,
      file
    });
    return sql2;
    function typed(value, type) {
      return new Parameter(value, type);
    }
    function sql2(strings, ...args) {
      const query = strings && Array.isArray(strings.raw) ? new Query(strings, args, handler2, cancel) : typeof strings === "string" && !args.length ? new Identifier(options.transform.column.to ? options.transform.column.to(strings) : strings) : new Builder(strings, args);
      return query;
    }
    function unsafe(string, args = [], options2 = {}) {
      arguments.length === 2 && !Array.isArray(args) && (options2 = args, args = []);
      const query = new Query([string], args, handler2, cancel, {
        prepare: false,
        ...options2,
        simple: "simple" in options2 ? options2.simple : args.length === 0
      });
      return query;
    }
    function file(path, args = [], options2 = {}) {
      arguments.length === 2 && !Array.isArray(args) && (options2 = args, args = []);
      const query = new Query([], args, (query2) => {
        fs.readFile(path, "utf8", (err, string) => {
          if (err)
            return query2.reject(err);
          query2.strings = [string];
          handler2(query2);
        });
      }, cancel, {
        ...options2,
        simple: "simple" in options2 ? options2.simple : args.length === 0
      });
      return query;
    }
  }
  async function listen(name, fn, onlisten) {
    const listener = { fn, onlisten };
    const sql2 = listen.sql || (listen.sql = Postgres({
      ...options,
      max: 1,
      idle_timeout: null,
      max_lifetime: null,
      fetch_types: false,
      onclose() {
        Object.entries(listen.channels).forEach(([name2, { listeners }]) => {
          delete listen.channels[name2];
          Promise.all(listeners.map((l) => listen(name2, l.fn, l.onlisten).catch(() => {})));
        });
      },
      onnotify(c, x) {
        c in listen.channels && listen.channels[c].listeners.forEach((l) => l.fn(x));
      }
    }));
    const channels = listen.channels || (listen.channels = {}), exists = name in channels;
    if (exists) {
      channels[name].listeners.push(listener);
      const result2 = await channels[name].result;
      listener.onlisten && listener.onlisten();
      return { state: result2.state, unlisten };
    }
    channels[name] = { result: sql2`listen ${sql2.unsafe('"' + name.replace(/"/g, '""') + '"')}`, listeners: [listener] };
    const result = await channels[name].result;
    listener.onlisten && listener.onlisten();
    return { state: result.state, unlisten };
    async function unlisten() {
      if (name in channels === false)
        return;
      channels[name].listeners = channels[name].listeners.filter((x) => x !== listener);
      if (channels[name].listeners.length)
        return;
      delete channels[name];
      return sql2`unlisten ${sql2.unsafe('"' + name.replace(/"/g, '""') + '"')}`;
    }
  }
  async function notify(channel, payload) {
    return await sql`select pg_notify(${channel}, ${"" + payload})`;
  }
  async function reserve() {
    const queue = queue_default();
    const c = open.length ? open.shift() : await new Promise((resolve, reject) => {
      const query = { reserve: resolve, reject };
      queries.push(query);
      closed.length && connect(closed.shift(), query);
    });
    move(c, reserved);
    c.reserved = () => queue.length ? c.execute(queue.shift()) : move(c, reserved);
    c.reserved.release = true;
    const sql2 = Sql(handler2);
    sql2.release = () => {
      c.reserved = null;
      onopen(c);
    };
    return sql2;
    function handler2(q) {
      c.queue === full ? queue.push(q) : c.execute(q) || move(c, full);
    }
  }
  async function begin(options2, fn) {
    !fn && (fn = options2, options2 = "");
    const queries2 = queue_default();
    let savepoints = 0, connection2, prepare = null;
    try {
      await sql.unsafe("begin " + options2.replace(/[^a-z ]/ig, ""), [], { onexecute }).execute();
      return await Promise.race([
        scope(connection2, fn),
        new Promise((_, reject) => connection2.onclose = reject)
      ]);
    } catch (error) {
      throw error;
    }
    async function scope(c, fn2, name) {
      const sql2 = Sql(handler2);
      sql2.savepoint = savepoint;
      sql2.prepare = (x) => prepare = x.replace(/[^a-z0-9$-_. ]/gi);
      let uncaughtError, result;
      name && await sql2`savepoint ${sql2(name)}`;
      try {
        result = await new Promise((resolve, reject) => {
          const x = fn2(sql2);
          Promise.resolve(Array.isArray(x) ? Promise.all(x) : x).then(resolve, reject);
        });
        if (uncaughtError)
          throw uncaughtError;
      } catch (e) {
        await (name ? sql2`rollback to ${sql2(name)}` : sql2`rollback`);
        throw e instanceof PostgresError && e.code === "25P02" && uncaughtError || e;
      }
      if (!name) {
        prepare ? await sql2`prepare transaction '${sql2.unsafe(prepare)}'` : await sql2`commit`;
      }
      return result;
      function savepoint(name2, fn3) {
        if (name2 && Array.isArray(name2.raw))
          return savepoint((sql3) => sql3.apply(sql3, arguments));
        arguments.length === 1 && (fn3 = name2, name2 = null);
        return scope(c, fn3, "s" + savepoints++ + (name2 ? "_" + name2 : ""));
      }
      function handler2(q) {
        q.catch((e) => uncaughtError || (uncaughtError = e));
        c.queue === full ? queries2.push(q) : c.execute(q) || move(c, full);
      }
    }
    function onexecute(c) {
      connection2 = c;
      move(c, reserved);
      c.reserved = () => queries2.length ? c.execute(queries2.shift()) : move(c, reserved);
    }
  }
  function move(c, queue) {
    c.queue.remove(c);
    queue.push(c);
    c.queue = queue;
    queue === open ? c.idleTimer.start() : c.idleTimer.cancel();
    return c;
  }
  function json(x) {
    return new Parameter(x, 3802);
  }
  function array(x, type) {
    if (!Array.isArray(x))
      return array(Array.from(arguments));
    return new Parameter(x, type || (x.length ? inferType(x) || 25 : 0), options.shared.typeArrayMap);
  }
  function handler(query) {
    if (ending)
      return query.reject(Errors.connection("CONNECTION_ENDED", options, options));
    if (open.length)
      return go(open.shift(), query);
    if (closed.length)
      return connect(closed.shift(), query);
    busy.length ? go(busy.shift(), query) : queries.push(query);
  }
  function go(c, query) {
    return c.execute(query) ? move(c, busy) : move(c, full);
  }
  function cancel(query) {
    return new Promise((resolve, reject) => {
      query.state ? query.active ? connection_default(options).cancel(query.state, resolve, reject) : query.cancelled = { resolve, reject } : (queries.remove(query), query.cancelled = true, query.reject(Errors.generic("57014", "canceling statement due to user request")), resolve());
    });
  }
  async function end({ timeout = null } = {}) {
    if (ending)
      return ending;
    await 1;
    let timer2;
    return ending = Promise.race([
      new Promise((r) => timeout !== null && (timer2 = setTimeout(destroy, timeout * 1000, r))),
      Promise.all(connections.map((c) => c.end()).concat(listen.sql ? listen.sql.end({ timeout: 0 }) : [], subscribe.sql ? subscribe.sql.end({ timeout: 0 }) : []))
    ]).then(() => clearTimeout(timer2));
  }
  async function close() {
    await Promise.all(connections.map((c) => c.end()));
  }
  async function destroy(resolve) {
    await Promise.all(connections.map((c) => c.terminate()));
    while (queries.length)
      queries.shift().reject(Errors.connection("CONNECTION_DESTROYED", options));
    resolve();
  }
  function connect(c, query) {
    move(c, connecting);
    c.connect(query);
    return c;
  }
  function onend(c) {
    move(c, ended);
  }
  function onopen(c) {
    if (queries.length === 0)
      return move(c, open);
    let max = Math.ceil(queries.length / (connecting.length + 1)), ready = true;
    while (ready && queries.length && max-- > 0) {
      const query = queries.shift();
      if (query.reserve)
        return query.reserve(c);
      ready = c.execute(query);
    }
    ready ? move(c, busy) : move(c, full);
  }
  function onclose(c, e) {
    move(c, closed);
    c.reserved = null;
    c.onclose && (c.onclose(e), c.onclose = null);
    options.onclose && options.onclose(c.id);
    queries.length && connect(c, queries.shift());
  }
}
function parseOptions(a, b2) {
  if (a && a.shared)
    return a;
  const env = process.env, o = (!a || typeof a === "string" ? b2 : a) || {}, { url, multihost } = parseUrl(a), query = [...url.searchParams].reduce((a2, [b3, c]) => (a2[b3] = c, a2), {}), host = o.hostname || o.host || multihost || url.hostname || env.PGHOST || "localhost", port = o.port || url.port || env.PGPORT || 5432, user = o.user || o.username || url.username || env.PGUSERNAME || env.PGUSER || osUsername();
  o.no_prepare && (o.prepare = false);
  query.sslmode && (query.ssl = query.sslmode, delete query.sslmode);
  "timeout" in o && (console.log("The timeout option is deprecated, use idle_timeout instead"), o.idle_timeout = o.timeout);
  query.sslrootcert === "system" && (query.ssl = "verify-full");
  const ints = ["idle_timeout", "connect_timeout", "max_lifetime", "max_pipeline", "backoff", "keep_alive"];
  const defaults = {
    max: globalThis.Cloudflare ? 3 : 10,
    ssl: false,
    sslnegotiation: null,
    idle_timeout: null,
    connect_timeout: 30,
    max_lifetime,
    max_pipeline: 100,
    backoff,
    keep_alive: 60,
    prepare: true,
    debug: false,
    fetch_types: true,
    publications: "alltables",
    target_session_attrs: null
  };
  return {
    host: Array.isArray(host) ? host : host.split(",").map((x) => x.split(":")[0]),
    port: Array.isArray(port) ? port : host.split(",").map((x) => parseInt(x.split(":")[1] || port)),
    path: o.path || host.indexOf("/") > -1 && host + "/.s.PGSQL." + port,
    database: o.database || o.db || (url.pathname || "").slice(1) || env.PGDATABASE || user,
    user,
    pass: o.pass || o.password || url.password || env.PGPASSWORD || "",
    ...Object.entries(defaults).reduce((acc, [k, d]) => {
      const value = k in o ? o[k] : (k in query) ? query[k] === "disable" || query[k] === "false" ? false : query[k] : env["PG" + k.toUpperCase()] || d;
      acc[k] = typeof value === "string" && ints.includes(k) ? +value : value;
      return acc;
    }, {}),
    connection: {
      application_name: env.PGAPPNAME || "postgres.js",
      ...o.connection,
      ...Object.entries(query).reduce((acc, [k, v]) => ((k in defaults) || (acc[k] = v), acc), {})
    },
    types: o.types || {},
    target_session_attrs: tsa(o, url, env),
    onnotice: o.onnotice,
    onnotify: o.onnotify,
    onclose: o.onclose,
    onparameter: o.onparameter,
    socket: o.socket,
    transform: parseTransform(o.transform || { undefined: undefined }),
    parameters: {},
    shared: { retries: 0, typeArrayMap: {} },
    ...mergeUserTypes(o.types)
  };
}
function tsa(o, url, env) {
  const x = o.target_session_attrs || url.searchParams.get("target_session_attrs") || env.PGTARGETSESSIONATTRS;
  if (!x || ["read-write", "read-only", "primary", "standby", "prefer-standby"].includes(x))
    return x;
  throw new Error("target_session_attrs " + x + " is not supported");
}
function backoff(retries) {
  return (0.5 + Math.random() / 2) * Math.min(3 ** retries / 100, 20);
}
function max_lifetime() {
  return 60 * (30 + Math.random() * 30);
}
function parseTransform(x) {
  return {
    undefined: x.undefined,
    column: {
      from: typeof x.column === "function" ? x.column : x.column && x.column.from,
      to: x.column && x.column.to
    },
    value: {
      from: typeof x.value === "function" ? x.value : x.value && x.value.from,
      to: x.value && x.value.to
    },
    row: {
      from: typeof x.row === "function" ? x.row : x.row && x.row.from,
      to: x.row && x.row.to
    }
  };
}
function parseUrl(url) {
  if (!url || typeof url !== "string")
    return { url: { searchParams: new Map } };
  let host = url;
  host = host.slice(host.indexOf("://") + 3).split(/[?/]/)[0];
  host = decodeURIComponent(host.slice(host.indexOf("@") + 1));
  const urlObj = new URL(url.replace(host, host.split(",")[0]));
  return {
    url: {
      username: decodeURIComponent(urlObj.username),
      password: decodeURIComponent(urlObj.password),
      host: urlObj.host,
      hostname: urlObj.hostname,
      port: urlObj.port,
      pathname: urlObj.pathname,
      searchParams: urlObj.searchParams
    },
    multihost: host.indexOf(",") > -1 && host
  };
}
function osUsername() {
  try {
    return os.userInfo().username;
  } catch (_) {
    return process.env.USERNAME || process.env.USER || process.env.LOGNAME;
  }
}

// src/db/postgres.ts
var DEFAULT_DATABASE_URL = "postgres://postgres:postgres@127.0.0.1:5432/entity_wars";
var databaseUrl = Bun.env.DATABASE_URL || DEFAULT_DATABASE_URL;

class AccountStatusUnavailableError extends Error {
}
var poolSize = Number(Bun.env.PG_POOL_SIZE || 10);
var idleTimeoutSeconds = Number(Bun.env.PG_IDLE_TIMEOUT_SECONDS || 30);
var connectTimeoutSeconds = Number(Bun.env.PG_CONNECT_TIMEOUT_SECONDS || 10);
var maxLifetimeSeconds = Number(Bun.env.PG_MAX_LIFETIME_SECONDS || 0);
var sql = src_default(databaseUrl, {
  max: Number.isFinite(poolSize) && poolSize > 0 ? poolSize : 10,
  idle_timeout: Number.isFinite(idleTimeoutSeconds) && idleTimeoutSeconds > 0 ? idleTimeoutSeconds : 30,
  connect_timeout: Number.isFinite(connectTimeoutSeconds) && connectTimeoutSeconds > 0 ? connectTimeoutSeconds : 10,
  max_lifetime: Number.isFinite(maxLifetimeSeconds) && maxLifetimeSeconds > 0 ? maxLifetimeSeconds : undefined,
  prepare: true
});
function getPostgres() {
  return sql;
}
async function upsertUser(user) {
  try {
    await sql`
			INSERT INTO users (id, email, display_name)
			VALUES (${user.id}, ${user.email}, ${user.displayName ?? null})
			ON CONFLICT (email)
			DO UPDATE SET display_name = EXCLUDED.display_name;
		`;
  } catch (err) {
    console.warn("[postgres] upsert user failed", err);
  }
}
async function isUserDisabled(userId) {
  let timer2;
  try {
    const query = sql`SELECT disabled FROM users WHERE id = ${userId}`;
    const timeoutMs = Number(Bun.env.AUTH_ACCOUNT_TIMEOUT_MS || 3000);
    const rows = await Promise.race([
      query,
      new Promise((_, reject) => {
        timer2 = setTimeout(() => reject(new Error("Account status query timed out")), Number.isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : 3000);
      })
    ]);
    const row = rows[0];
    return row?.disabled === true;
  } catch (err) {
    console.warn("[postgres] user disabled check failed", err);
    if ([Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((v) => ["production", "prod"].includes((v ?? "").toLowerCase()))) {
      throw new AccountStatusUnavailableError("Account status temporarily unavailable");
    }
    return false;
  } finally {
    if (timer2)
      clearTimeout(timer2);
  }
}
async function pingPostgres() {
  try {
    await sql`SELECT 1`;
    return true;
  } catch {
    return false;
  }
}
async function postgresExample() {
  try {
    await sql`
			CREATE TABLE IF NOT EXISTS __example_kv (
				key text PRIMARY KEY,
				value text NOT NULL,
				updated_at timestamptz NOT NULL DEFAULT now()
			);
		`;
    await sql`
			INSERT INTO __example_kv (key, value)
			VALUES ('hello', 'world')
			ON CONFLICT (key)
			DO UPDATE SET value = excluded.value, updated_at = now();
		`;
    const rows = await sql`SELECT key, value FROM __example_kv WHERE key = 'hello'`;
    const first = rows[0];
    console.log("[postgres] example row", first ?? null);
  } catch (err) {
    console.warn("[postgres] example skipped", err);
  }
}

// src/middleware/auth.ts
var inMemorySessions = new Map;
var revokedSessions = new Set;
var production2 = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((v) => ["production", "prod"].includes((v ?? "").toLowerCase()));
function makeSessionKey(token) {
  return `sess:${token}`;
}
function extractToken(req) {
  const authHeader = req.headers.get("authorization");
  if (authHeader) {
    const parts = authHeader.split(" ");
    if (parts.length == 2 && parts[0].toLowerCase() == "bearer") {
      return parts[1];
    }
  }
  return req.headers.get("x-dev-token");
}
async function issueSession(userId, ttlMs) {
  const token = crypto.randomUUID();
  const now = Date.now();
  const record = {
    userId,
    createdAt: now,
    expiresAt: now + ttlMs
  };
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.set(makeSessionKey(token), JSON.stringify(record), "PX", ttlMs);
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] redis session write failed", err);
  }
  if (production2 && !persisted)
    throw new Error("Session storage unavailable");
  inMemorySessions.set(token, record);
  return token;
}
async function revokeSession(token) {
  inMemorySessions.delete(token);
  revokedSessions.add(token);
  let persisted = false;
  try {
    const redis2 = getRedis();
    if (await ensureRedisReady()) {
      await redis2.del(makeSessionKey(token));
      persisted = true;
    }
  } catch (err) {
    console.warn("[auth] redis session delete failed", err);
  }
  if (production2 && !persisted)
    throw new Error("Session revocation unavailable");
}
async function getSession(token) {
  if (revokedSessions.has(token))
    return null;
  const now = Date.now();
  const cached = inMemorySessions.get(token);
  if (cached) {
    if (cached.expiresAt > now && !production2) {
      return cached;
    }
    inMemorySessions.delete(token);
  }
  try {
    const redis2 = getRedis();
    if (!await ensureRedisReady()) {
      return !production2 && cached && cached.expiresAt > Date.now() ? cached : null;
    }
    const raw = await redis2.get(makeSessionKey(token));
    if (!raw) {
      return null;
    }
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed.userId != "string" || !Number.isFinite(parsed.expiresAt)) {
      return null;
    }
    if (parsed.expiresAt <= now) {
      await redis2.del(makeSessionKey(token));
      return null;
    }
    inMemorySessions.set(token, parsed);
    return parsed;
  } catch (err) {
    console.warn("[auth] redis session read failed", err);
    return !production2 && cached && cached.expiresAt > Date.now() ? cached : null;
  }
}

// src/middleware/rateLimit.ts
var memoryLimits = new Map;
function limitWithoutRedis(key, options) {
  const isProduction = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((value) => value?.toLowerCase() == "production" || value?.toLowerCase() == "prod");
  if (isProduction) {
    return { allowed: false, bypass: false, status: 503, message: "Rate limit unavailable." };
  }
  const now = Date.now();
  for (const [storedKey, entry2] of memoryLimits) {
    if (entry2.expiresAt <= now)
      memoryLimits.delete(storedKey);
  }
  const windowMs = Math.max(1, Math.floor(options.windowSeconds * 1000));
  const max = Math.max(1, Math.floor(options.max));
  let entry = memoryLimits.get(key);
  if (!entry) {
    entry = { count: 0, expiresAt: now + windowMs };
    memoryLimits.set(key, entry);
  }
  entry.count += 1;
  const remaining = Math.max(0, max - entry.count);
  const resetSeconds = Math.max(1, Math.ceil((entry.expiresAt - now) / 1000));
  return {
    allowed: entry.count <= max,
    bypass: false,
    remaining,
    resetSeconds,
    ...entry.count > max ? { message: "Rate limit exceeded." } : {}
  };
}
function buildKey(options) {
  const keyBy = options.keyBy ?? "ip";
  const ip = options.ip ?? "unknown";
  const userId = options.userId ?? "anon";
  const route = options.route ?? "global";
  switch (keyBy) {
    case "user":
      return `${options.keyPrefix}:${userId}`;
    case "ip+route":
      return `${options.keyPrefix}:${ip}:${route}`;
    default:
      return `${options.keyPrefix}:${ip}`;
  }
}
async function rateLimit(options) {
  const key = buildKey(options);
  try {
    const redis2 = getRedis();
    if (!await ensureRedisReady()) {
      return limitWithoutRedis(key, options);
    }
    const count = await redis2.incr(key);
    if (count == 1) {
      await redis2.expire(key, options.windowSeconds);
    }
    const remaining = Math.max(0, options.max - count);
    if (count > options.max) {
      return {
        allowed: false,
        bypass: false,
        remaining,
        resetSeconds: options.windowSeconds,
        message: "Rate limit exceeded."
      };
    }
    return { allowed: true, bypass: false, remaining, resetSeconds: options.windowSeconds };
  } catch (err) {
    console.warn("[rate-limit] redis unavailable", err);
    return limitWithoutRedis(key, options);
  }
}

// src/observability/logger.ts
function log(level, message, fields = {}) {
  const payload = {
    ts: new Date().toISOString(),
    level,
    msg: message,
    ...fields
  };
  const line = JSON.stringify(payload);
  if (level == "error") {
    console.error(line);
  } else if (level == "warn") {
    console.warn(line);
  } else {
    console.log(line);
  }
}
function logInfo(message, fields) {
  log("info", message, fields);
}
function logWarn(message, fields) {
  log("warn", message, fields);
}
function logError(message, fields) {
  log("error", message, fields);
}

// src/jobs/queue.ts
async function enqueueJob(type, payload, runAt) {
  const sql2 = getPostgres();
  const id = crypto.randomUUID();
  const now = runAt ?? new Date;
  try {
    await sql2`
			INSERT INTO jobs (id, type, payload, run_at, status, attempts)
			VALUES (${id}, ${type}, ${JSON.stringify(payload)}, ${now}, 'queued', 0)
		`;
    return id;
  } catch (err) {
    logWarn("job enqueue failed", { type, error: String(err) });
    return null;
  }
}
async function getJobQueueSize() {
  const sql2 = getPostgres();
  try {
    const rows = await sql2`SELECT COUNT(*) as count FROM jobs WHERE status = 'queued'`;
    const row = rows[0];
    const raw = row?.count ?? 0;
    return typeof raw == "string" ? Number(raw) : Number(raw);
  } catch (err) {
    logWarn("job queue size failed", { error: String(err) });
    return 0;
  }
}

// src/observability/metrics.ts
var metrics = {
  requests: 0,
  errors: 0,
  latencySum: 0,
  latencyCount: 0,
  statusCounts: new Map
};
function recordRequest(status, latencyMs) {
  metrics.requests += 1;
  metrics.latencySum += latencyMs;
  metrics.latencyCount += 1;
  const key = String(status);
  metrics.statusCounts.set(key, (metrics.statusCounts.get(key) ?? 0) + 1);
}
function recordError() {
  metrics.errors += 1;
}
function snapshotMetrics() {
  const avg = metrics.latencyCount > 0 ? metrics.latencySum / metrics.latencyCount : 0;
  const statusCounts = {};
  for (const [key, value] of metrics.statusCounts.entries()) {
    statusCounts[key] = value;
  }
  return {
    requests_total: metrics.requests,
    errors_total: metrics.errors,
    avg_latency_ms: Math.round(avg),
    status_counts: statusCounts
  };
}

// src/spell_research.ts
import { readFileSync } from "fs";
import { resolve } from "path";
function readCatalog(file, key) {
  try {
    const data = JSON.parse(readFileSync(resolve(import.meta.dir, "..", "..", "data", file), "utf8"));
    return Array.isArray(data[key]) ? data[key] : [];
  } catch (error) {
    console.warn(`[spells] Cannot load ${file}`, error);
    return [];
  }
}
var entities = new Map;
for (const entity of readCatalog("entities.json", "entities")) {
  if (typeof entity?.id === "string" && typeof entity?.type === "string")
    entities.set(entity.id, entity.type);
}
var spells = new Map;
for (const spell of readCatalog("spells.json", "spells")) {
  if (typeof spell?.id === "string" && typeof spell?.type === "string" && !spells.has(spell.id))
    spells.set(spell.id, spell);
}
function isResearchable(entityId, spellId) {
  const type = entities.get(entityId);
  const spell = spells.get(spellId);
  return !!type && !!spell && (spell.type === "universal" || spell.type === "hybrid") && Array.isArray(spell.eligible_types) && spell.eligible_types.includes(type);
}
function featuredSpellIds(type, towerLevel, now, rotationSeconds = 86400) {
  const index = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].indexOf(type);
  if (index < 0 || !Number.isFinite(now) || !Number.isFinite(rotationSeconds) || rotationSeconds <= 0)
    return [];
  const candidates = [...spells.values()].filter((spell) => (spell.type === "universal" || spell.type === "hybrid") && Array.isArray(spell.eligible_types) && spell.eligible_types.includes(type) && Number.isInteger(spell.tower_level_required) && spell.tower_level_required >= 1 && spell.tower_level_required <= towerLevel).map((spell) => spell.id).sort();
  if (!candidates.length)
    return [];
  const day = Math.floor(now / (rotationSeconds * 1000));
  const start = ((day + index * 7) % candidates.length + candidates.length) % candidates.length;
  const step = Math.max(1, Math.floor(candidates.length / 3));
  return Array.from({ length: Math.min(3, candidates.length) }, (_, k) => candidates[(start + k * step) % candidates.length]);
}
function validLoadout(entityId, ids, learned) {
  const type = entities.get(entityId);
  if (!type || !Array.isArray(ids) || ids.length !== 4 || ids.some((id) => typeof id !== "string") || new Set(ids).size !== 4)
    return false;
  return ids.every((id) => {
    const spell = spells.get(id);
    return !!spell && (spell.type === type || isResearchable(entityId, id) && (learned[entityId] ?? []).includes(id));
  });
}
function normalizeSpellProgress(raw) {
  const learned = {};
  const source = raw?.learned_by_entity;
  if (source && typeof source === "object" && !Array.isArray(source)) {
    for (const [entityId, values2] of Object.entries(source)) {
      if (!entities.has(entityId) || !Array.isArray(values2))
        continue;
      learned[entityId] = [...new Set(values2.filter((id) => typeof id === "string" && isResearchable(entityId, id)))].slice(0, 20);
    }
  }
  const project = raw?.active_research;
  let active = null;
  if (project && typeof project.entity_id === "string" && typeof project.spell_id === "string" && isResearchable(project.entity_id, project.spell_id) && Number.isFinite(project.started_at) && Number.isFinite(project.completes_at) && project.started_at >= 0 && project.completes_at >= project.started_at && !learned[project.entity_id]?.includes(project.spell_id)) {
    active = { entity_id: project.entity_id, spell_id: project.spell_id, started_at: project.started_at, completes_at: project.completes_at };
  }
  const equipped = { attack: {}, defense: {} };
  for (const mode of ["attack", "defense"]) {
    const entries = raw?.equipped_by_mode?.[mode];
    if (!entries || typeof entries !== "object" || Array.isArray(entries))
      continue;
    for (const [entityId, ids] of Object.entries(entries)) {
      if (validLoadout(entityId, ids, learned))
        equipped[mode][entityId] = [...ids];
    }
  }
  return { learned_by_entity: learned, active_research: active, equipped_by_mode: equipped };
}
function setSpellLoadout(state, payload) {
  const mode = typeof payload?.mode === "string" ? payload.mode : "";
  const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
  if (mode !== "attack" && mode !== "defense")
    return "Invalid loadout mode.";
  if (!validLoadout(entityId, payload?.spell_ids, state.spell_progress.learned_by_entity))
    return "Invalid or unlearned spell loadout.";
  state.spell_progress.equipped_by_mode[mode][entityId] = [...payload.spell_ids];
  return null;
}
function startSpellResearch(state, payload, now, resources, balance = {}, timeMultiplier = 1) {
  const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
  const spellId = typeof payload?.spell_id === "string" ? payload.spell_id : "";
  if (!isResearchable(entityId, spellId))
    return "Unknown or incompatible entity and spell.";
  const progress = state.spell_progress;
  if (progress.learned_by_entity[entityId]?.includes(spellId))
    return "Spell already learned.";
  if (progress.active_research)
    return "Spell research already in progress.";
  if ((progress.learned_by_entity[entityId]?.length ?? 0) >= 20)
    return "Entity spell limit reached.";
  const spell = spells.get(spellId);
  if (!Number.isInteger(spell.tower_level_required) || (spell.tower_level_required ?? 0) < 1 || !Number.isInteger(spell.research_time_sec) || (spell.research_time_sec ?? 0) <= 0 || !spell.research_cost || typeof spell.research_cost !== "object" || Array.isArray(spell.research_cost) || Object.keys(spell.research_cost).length === 0)
    return "Invalid spell research data.";
  if ((state.lab.buildings.ultrahit_tower?.level ?? 0) < spell.tower_level_required)
    return "Spell Tower level too low.";
  const discount = balance.spell_featured_discount_pct ?? 0.2;
  const rotation = balance.spell_featured_rotation_seconds ?? 86400;
  if (typeof discount !== "number" || !Number.isFinite(discount) || discount < 0 || discount > 1 || typeof rotation !== "number" || !Number.isFinite(rotation) || rotation <= 0)
    return "Invalid featured research configuration.";
  const featured = featuredSpellIds(entities.get(entityId), state.lab.buildings.ultrahit_tower?.level ?? 0, now, rotation).includes(spellId);
  const cost = {};
  for (const [id, amount] of Object.entries(spell.research_cost)) {
    if (!resources.has(id) || !Number.isSafeInteger(amount) || amount < 0)
      return "Invalid spell research cost.";
    cost[id] = featured && amount > 0 ? Math.max(1, Math.ceil(amount * (1 - discount))) : amount;
    if ((state.wallet[id] ?? 0) < cost[id])
      return "Insufficient resources.";
  }
  for (const [id, amount] of Object.entries(cost))
    state.wallet[id] -= amount;
  progress.active_research = { entity_id: entityId, spell_id: spellId, started_at: now, completes_at: now + Math.max(1, spell.research_time_sec * timeMultiplier) * 1000 };
  return null;
}
function claimSpellResearch(state, payload, now) {
  const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
  const spellId = typeof payload?.spell_id === "string" ? payload.spell_id : "";
  if (!isResearchable(entityId, spellId))
    return "Unknown or incompatible entity and spell.";
  const progress = state.spell_progress;
  if (progress.learned_by_entity[entityId]?.includes(spellId))
    return null;
  const active = progress.active_research;
  if (!active || active.entity_id !== entityId || active.spell_id !== spellId)
    return "Spell research mismatch.";
  if (active.completes_at > now)
    return "Spell research not complete.";
  const learned = progress.learned_by_entity[entityId] ?? [];
  if (learned.length >= 20)
    return "Entity spell limit reached.";
  progress.learned_by_entity[entityId] = [...learned, spellId];
  progress.active_research = null;
  return null;
}

// src/combat_rewards.ts
function validReward(value) {
  return value && typeof value === "object" && !Array.isArray(value) && (value.resource_id === "arcane_shard" && value.amount === 1 || value.resource_id === "time_crystal" && (value.amount === 1 || value.amount === 3));
}

class CombatRewardError extends Error {
  status;
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
function claimVerifiedCombatReward(db, matchId, playerId, apply) {
  return db.transaction(() => {
    const row = db.query("SELECT player_id, status, reward_json, claimed_at FROM combat_reward_receipts WHERE match_id = ?").get(matchId);
    if (!row || row.player_id !== playerId || row.status !== "VERIFIED_WIN")
      throw new CombatRewardError(404, "Verified combat reward not found.");
    let reward;
    try {
      reward = JSON.parse(row.reward_json);
    } catch {
      throw new CombatRewardError(500, "Invalid stored combat reward.");
    }
    if (reward !== null && (!validReward(reward) || Object.keys(reward).length !== 2))
      throw new CombatRewardError(500, "Invalid stored combat reward.");
    const duplicate = row.claimed_at !== null;
    const state = apply(reward, duplicate);
    if (!duplicate)
      db.prepare("UPDATE combat_reward_receipts SET claimed_at = ? WHERE match_id = ? AND claimed_at IS NULL").run(Date.now(), matchId);
    return { reward, duplicate, state };
  }).immediate();
}

// src/index.ts
var IS_PRODUCTION = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((value) => value?.toLowerCase() == "production" || value?.toLowerCase() == "prod");
function economicSecret(name, developmentDefault) {
  const secret = Bun.env[name];
  if (IS_PRODUCTION && (!secret || secret.trim().length < 32 || ["dev_experiment_secret", "dev_trade_secret", "dev_world_secret"].includes(secret.trim()))) {
    throw new Error(`${name} must be configured with a non-development secret of at least 32 characters in production.`);
  }
  return secret || developmentDefault;
}
var EXPERIMENT_SECRET = economicSecret("EXPERIMENT_SECRET", "dev_experiment_secret");
var TRADE_SECRET = economicSecret("TRADE_SECRET", "dev_trade_secret");
var WORLD_SECRET = economicSecret("WORLD_SECRET", "dev_world_secret");
var TOKEN_SIGNING_SECRET = Bun.env.TOKEN_SIGNING_SECRET || "";
function normalizeHomunculusProgress(value) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    return {};
  const result = {};
  for (const [id, raw] of Object.entries(value)) {
    if (!staticData.homunculusIds.has(id) || !raw || typeof raw !== "object" || Array.isArray(raw))
      continue;
    const entry = raw;
    const level = Number(entry.level);
    const progress = { level: Number.isInteger(level) ? Math.max(0, Math.min(10, level)) : 0 };
    if (typeof entry.mutation_id === "string" && staticData.mutationIds.has(entry.mutation_id)) {
      progress.mutation_id = entry.mutation_id;
      progress.mutation_changed_at = clampInt(entry.mutation_changed_at, 0, Number.MAX_SAFE_INTEGER);
    }
    result[id] = progress;
  }
  return result;
}
function normalizeItemProgress(value) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    return {};
  const result = {};
  for (const [id, raw] of Object.entries(value)) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(id) || !raw || typeof raw !== "object" || Array.isArray(raw))
      continue;
    const item = raw;
    const level = Number(item.level);
    result[id] = {
      ...item,
      level: Number.isInteger(level) ? Math.max(0, Math.min(10, level)) : 0
    };
  }
  return result;
}

class HttpError extends Error {
  status;
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
var config = loadConfig();
var staticData = loadStaticData();
var ACCESS_TTL_MS = getEnvNumber("ACCESS_TTL_SECONDS", 15 * 60) * 1000;
var REFRESH_TTL_MS = getEnvNumber("REFRESH_TTL_SECONDS", 7 * 24 * 60 * 60) * 1000;
var EXPENSIVE_RATE_WINDOW = getEnvNumber("EXPENSIVE_RATE_LIMIT_WINDOW_SECONDS", 60);
var EXPENSIVE_RATE_MAX = getEnvNumber("EXPENSIVE_RATE_LIMIT_MAX", 60);
var CORS_ORIGINS = parseCorsOrigins();
var dbFilePath = ensureDbPath(config.dbPath);
var db = new Database(dbFilePath);
db.exec("PRAGMA busy_timeout = 5000;");
for (let attempt = 0;; attempt++) {
  try {
    db.exec("PRAGMA journal_mode = WAL;");
    break;
  } catch (err) {
    if (attempt >= 50 || typeof err !== "object" || err === null || !String(err.code).startsWith("SQLITE_BUSY"))
      throw err;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
  }
}
var getPlayerByIdStmt = db.prepare("SELECT player_id, display_name, state_json, updated_at FROM players WHERE player_id = ?");
var getPlayerByNameStmt = db.prepare("SELECT player_id, display_name, state_json, updated_at FROM players WHERE display_name = ?");
var insertPlayerStmt = db.prepare("INSERT INTO players (player_id, display_name, state_json, updated_at) VALUES (?, ?, ?, ?)");
var updatePlayerStmt = db.prepare("UPDATE players SET state_json = json_set(?, '$.state_revision', CASE WHEN json_valid(state_json) THEN MAX(0, CAST(COALESCE(json_extract(state_json, '$.state_revision'), 0) AS INTEGER)) + 1 ELSE 1 END), updated_at = ? WHERE player_id = ?");
var getActionStmt = db.prepare("SELECT player_id, action_type, payload_json, result_state_json FROM action_log WHERE player_id = ? AND client_action_id = ?");
var insertActionStmt = db.prepare("INSERT INTO action_log (player_id, client_action_id, action_type, payload_json, result_state_json, created_at) VALUES (?, ?, ?, ?, ?, ?)");
var insertOrderStmt = db.prepare("INSERT INTO market_orders (order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
var getOrderStmt = db.prepare("SELECT order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at FROM market_orders WHERE order_id = ?");
var updateOrderStatusStmt = db.prepare("UPDATE market_orders SET status = ? WHERE order_id = ?");
var getOrderFillsSumStmt = db.prepare("SELECT COALESCE(SUM(amount), 0) as filled FROM market_fills WHERE order_id = ?");
var insertFillStmt = db.prepare("INSERT INTO market_fills (fill_id, order_id, buyer_id, amount, total_price, fee, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)");
var getEscrowStmt = db.prepare("SELECT amount FROM escrow WHERE player_id = ? AND resource_id = ?");
var addEscrowStmt = db.prepare("INSERT INTO escrow (player_id, resource_id, amount) VALUES (?, ?, ?) ON CONFLICT(player_id, resource_id) DO UPDATE SET amount = amount + excluded.amount");
var setEscrowStmt = db.prepare("INSERT INTO escrow (player_id, resource_id, amount) VALUES (?, ?, ?) ON CONFLICT(player_id, resource_id) DO UPDATE SET amount = excluded.amount");
var listOrdersStmt = db.prepare("SELECT order_id, seller_id, type, resource_id, amount, price_resource_id, price_amount, fee_bps, status, created_at FROM market_orders WHERE (? IS NULL OR resource_id = ?) AND (? IS NULL OR type = ?) AND (? IS NULL OR status = ?) AND (? IS NULL OR seller_id = ?) ORDER BY created_at DESC LIMIT ?");
var insertTradeJobStmt = db.prepare("INSERT INTO trade_jobs (job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
var getTradeJobStmt = db.prepare("SELECT job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at FROM trade_jobs WHERE job_id = ?");
var listTradeJobsStmt = db.prepare("SELECT job_id, provider_id, input_resource_id, input_amount, output_resource_id, output_min, output_max, duration_sec, commission_resource_id, commission_amount, queue_limit, status, created_at FROM trade_jobs WHERE (? IS NULL OR output_resource_id = ?) AND (? IS NULL OR status = ?) ORDER BY created_at DESC LIMIT ?");
var insertTradeRunStmt = db.prepare("INSERT INTO trade_job_runs (run_id, job_id, customer_id, submitted_at, completes_at, input_locked, status, output_amount, rng_seed) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
var getTradeRunStmt = db.prepare("SELECT run_id, job_id, customer_id, submitted_at, completes_at, input_locked, status, output_amount, rng_seed FROM trade_job_runs WHERE run_id = ?");
var updateTradeRunStmt = db.prepare("UPDATE trade_job_runs SET status = ?, output_amount = ? WHERE run_id = ?");
var countTradeRunsStmt = db.prepare("SELECT COUNT(*) as count FROM trade_job_runs WHERE job_id = ? AND status = ?");
var insertAuditStmt = db.prepare("INSERT INTO audit_wallet (audit_id, player_id, delta_wallet, reason, related_id, created_at) VALUES (?, ?, ?, ?, ?, ?)");
var countAuditStmt = db.prepare("SELECT COUNT(*) as count FROM audit_wallet WHERE player_id = ?");
var getWorldStmt = db.prepare("SELECT state_json, updated_at FROM world LIMIT 1");
var insertWorldStmt = db.prepare("INSERT INTO world (state_json, updated_at) VALUES (?, ?)");
var updateWorldStmt = db.prepare("UPDATE world SET state_json = ?, updated_at = ?");
var bossIpWindow = new Map;
var sockets = new Set;
var DEBUG_BYPASS = !IS_PRODUCTION && Bun.env.DEBUG_BYPASS == "1";
function developmentLoginAllowed(address, origin) {
  if (IS_PRODUCTION || !address)
    return false;
  if (origin) {
    try {
      const parsed = new URL(origin);
      if (!["http:", "https:"].includes(parsed.protocol) || !["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname))
        return false;
    } catch {
      return false;
    }
  }
  const peer = address.startsWith("::ffff:") ? address.slice(7) : address;
  if (peer === "127.0.0.1" || peer === "::1")
    return true;
  if (Bun.env.DEV_DOCKER_LOCAL_LOGIN !== "1")
    return false;
  try {
    for (const line of readFileSync2("/proc/net/route", "utf8").split(`
`).slice(1)) {
      const fields = line.trim().split(/\s+/);
      if (fields[1] !== "00000000" || !/^[0-9A-Fa-f]{8}$/.test(fields[2] ?? ""))
        continue;
      const gateway = Number.parseInt(fields[2], 16);
      const ip = [gateway & 255, gateway >>> 8 & 255, gateway >>> 16 & 255, gateway >>> 24 & 255].join(".");
      if (peer === ip && ip !== "0.0.0.0")
        return true;
    }
  } catch {}
  return false;
}
function loadConfig() {
  const env = (Bun.env.NODE_ENV || Bun.env.BUN_ENV || "").toLowerCase();
  let merged = mergeConfig(default_default, {});
  if (env == "production" || env == "prod") {
    merged = mergeConfig(merged, prod_default);
  } else {
    merged = mergeConfig(merged, dev_local_default);
  }
  merged.dbPath = Bun.env.DB_PATH || merged.dbPath;
  merged.port = Math.max(1, Math.min(65535, Math.trunc(getEnvNumber("PORT", merged.port))));
  merged.host = Bun.env.HOST || merged.host;
  const maxBody = getEnvNumber("MAX_BODY_BYTES", merged.maxBodyBytes);
  const tokenSeconds = getEnvNumber("SESSION_TTL_SECONDS", merged.tokenTtlMs / 1000);
  merged.maxBodyBytes = Math.max(1024, maxBody);
  merged.tokenTtlMs = Math.max(1000, tokenSeconds * 1000);
  return merged;
}
function mergeConfig(base, override) {
  const rateLimit2 = { ...base.rateLimit, ...override.rateLimit || {} };
  return { ...base, ...override, rateLimit: rateLimit2 };
}
function getEnvNumber(name, fallback) {
  const raw = Bun.env[name];
  if (raw == null || raw == "") {
    return fallback;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}
function parseCorsOrigins() {
  const raw = Bun.env.CORS_ORIGINS;
  if (!raw) {
    return [];
  }
  return raw.split(",").map((value) => value.trim()).filter((value) => value.length > 0);
}
function ensureDbPath(path) {
  const resolved = resolve2(process.cwd(), path);
  const dir = dirname(resolved);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  return resolved;
}
function normalizeLoginEmail(name) {
  const trimmed = name.trim();
  if (trimmed.includes("@")) {
    return trimmed.toLowerCase();
  }
  const slug = trimmed.toLowerCase().replace(/[^a-z0-9]+/g, ".").replace(/^\.+|\.+$/g, "");
  return `${slug || "dev"}@dev.local`;
}
function getClientIp(req) {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0].trim();
  }
  const real = req.headers.get("x-real-ip");
  if (real) {
    return real.trim();
  }
  return "unknown";
}
function getRequestId(req) {
  const existing = req.headers.get("x-request-id");
  if (existing && existing.length > 0) {
    return existing;
  }
  return crypto.randomUUID();
}
function isDebugBypass(req) {
  if (!DEBUG_BYPASS) {
    return false;
  }
  const header = req.headers.get("x-debug-bypass");
  if (!header) {
    return false;
  }
  return header == "1" || header.toLowerCase() == "true";
}
function isOriginAllowed(origin) {
  if (CORS_ORIGINS.length == 0) {
    const env = (Bun.env.NODE_ENV || Bun.env.BUN_ENV || "").toLowerCase();
    if (env == "production" || env == "prod") {
      return false;
    }
    return origin.startsWith("http://localhost") || origin.startsWith("http://127.0.0.1");
  }
  if (CORS_ORIGINS.includes("*")) {
    return true;
  }
  return CORS_ORIGINS.includes(origin);
}
function buildCorsHeaders(req) {
  const origin = req.headers.get("origin");
  if (!origin) {
    return {};
  }
  if (!isOriginAllowed(origin)) {
    return {};
  }
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Dev-Token,X-Request-Id",
    "Access-Control-Max-Age": "600",
    Vary: "Origin"
  };
}
function applyResponseHeaders(res, ctx, corsHeaders) {
  const headers = new Headers(res.headers);
  headers.set("X-Request-Id", ctx.requestId);
  if (ctx.rateLimitBypass) {
    headers.set("X-RateLimit-Bypass", "1");
  }
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("X-Frame-Options", "DENY");
  headers.set("Referrer-Policy", "no-referrer");
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  return new Response(res.body, { status: res.status, headers });
}
async function applyRateLimit(ctx, options) {
  const result = await rateLimit({
    ...options,
    ip: ctx.ip,
    route: options.route ?? ctx.path
  });
  if (result.bypass) {
    ctx.rateLimitBypass = true;
  }
  if (!result.allowed) {
    logWarn(result.status == 503 ? "rate limit unavailable" : "rate limit exceeded", {
      ip: ctx.ip,
      path: ctx.path,
      key: options.keyPrefix
    });
    throw new HttpError(result.status ?? 429, result.message || "Rate limit exceeded.");
  }
}
async function readJson(req, maxBytes) {
  const buf = await req.arrayBuffer();
  if (buf.byteLength > maxBytes) {
    throw new HttpError(413, "Body too large.");
  }
  if (buf.byteLength == 0) {
    return {};
  }
  try {
    return JSON.parse(new TextDecoder().decode(buf));
  } catch {
    throw new HttpError(400, "Invalid JSON.");
  }
}
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}
function getSchemaVersion() {
  try {
    const row = db.query("SELECT id FROM schema_migrations ORDER BY applied_at DESC LIMIT 1").get();
    return row?.id ?? null;
  } catch {
    return null;
  }
}
async function staticVersionResponse() {
  const cacheKey = "cache:static:version";
  const schemaVersion = getSchemaVersion();
  const staticVersion = staticData.balance?.static_version ?? null;
  const payload = {
    ok: true,
    api_version: config.apiVersion,
    env: config.env,
    server_time_unix_ms: Date.now(),
    schema_version: schemaVersion,
    static_version: staticVersion
  };
  let redisHealthy = true;
  try {
    const redis2 = getRedis();
    if (!await ensureRedisReady()) {
      throw new Error("Redis unavailable");
    }
    const cached = await redis2.get(cacheKey);
    if (cached) {
      return jsonResponse(JSON.parse(cached));
    }
  } catch (err) {
    console.warn("[cache] static/version redis read failed", err);
    redisHealthy = false;
  }
  if (redisHealthy) {
    try {
      const redis2 = getRedis();
      await redis2.set(cacheKey, JSON.stringify(payload), "EX", 60);
    } catch (err) {
      console.warn("[cache] static/version redis write failed", err);
    }
  }
  return jsonResponse(payload);
}
async function healthResponse() {
  const [pgOk, redisOk] = await Promise.all([pingPostgres(), pingRedis()]);
  return jsonResponse({
    ok: true,
    postgres: pgOk ? "up" : "down",
    redis: redisOk ? "up" : "down",
    version: config.apiVersion
  });
}
async function metricsResponse() {
  const [pgOk, redisOk, queueSize] = await Promise.all([
    pingPostgres(),
    pingRedis(),
    getJobQueueSize()
  ]);
  return jsonResponse({
    ok: true,
    ...snapshotMetrics(),
    postgres: pgOk ? "up" : "down",
    redis: redisOk ? "up" : "down",
    job_queue_size: queueSize
  });
}
function stateResponse(state, ok = true, error, status = 200) {
  const current = getPlayerByIdStmt.get(state.player_id);
  const authoritative = current ? safeParseState(current.state_json, state.player_id, state.display_name ?? "") ?? state : state;
  return jsonResponse({
    ok,
    server_time_unix_ms: Date.now(),
    updated_player_state: authoritative,
    error: error ?? null
  }, status);
}
function stateResponseExtra(state, extra = {}) {
  const current = getPlayerByIdStmt.get(state.player_id);
  const authoritative = current ? safeParseState(current.state_json, state.player_id, state.display_name ?? "") ?? state : state;
  return jsonResponse({
    ok: true,
    server_time_unix_ms: Date.now(),
    updated_player_state: authoritative,
    ...extra
  });
}
function loginResponse(playerId, token) {
  return jsonResponse({
    ok: true,
    server_time_unix_ms: Date.now(),
    player_id: playerId,
    token
  });
}
function tokenPairResponse(accessToken, refreshToken) {
  return jsonResponse({
    ok: true,
    server_time_unix_ms: Date.now(),
    access_token: accessToken,
    refresh_token: refreshToken,
    access_expires_in: Math.floor(ACCESS_TTL_MS / 1000),
    refresh_expires_in: Math.floor(REFRESH_TTL_MS / 1000)
  });
}
function errorResponse(message, status) {
  return jsonResponse({
    ok: false,
    server_time_unix_ms: Date.now(),
    error: message
  }, status);
}
function getSessionTtlMs() {
  const envSeconds = Number(Bun.env.SESSION_TTL_SECONDS || 0);
  if (Number.isFinite(envSeconds) && envSeconds > 0) {
    return Math.floor(envSeconds * 1000);
  }
  return config.tokenTtlMs;
}
async function issueToken(playerId) {
  return issueSession(playerId, getSessionTtlMs());
}
async function requireAuth(req, ctx) {
  const token = extractToken(req);
  if (!token) {
    throw new HttpError(401, "Missing auth token.");
  }
  const access = await getAccessToken(token);
  const legacy = access ? null : await getSession(token);
  const entry = access ?? legacy;
  if (!entry) {
    throw new HttpError(401, "Invalid token.");
  }
  if (await isUserDisabled(entry.userId)) {
    throw new HttpError(403, "User disabled.");
  }
  if (ctx) {
    ctx.userId = entry.userId;
  }
  return entry.userId;
}
async function tryAuth(req, ctx) {
  const token = extractToken(req);
  if (!token) {
    return null;
  }
  const access = await getAccessToken(token);
  const legacy = access ? null : await getSession(token);
  const entry = access ?? legacy;
  if (!entry) {
    return null;
  }
  if (await isUserDisabled(entry.userId)) {
    return null;
  }
  if (ctx) {
    ctx.userId = entry.userId;
  }
  return entry.userId;
}
function findOrCreatePlayer(name) {
  const existing = getPlayerByNameStmt.get(name);
  if (existing) {
    return { player_id: existing.player_id, display_name: existing.display_name };
  }
  const playerId = crypto.randomUUID();
  const now = Date.now();
  const state = createDefaultState(playerId, name, now, true);
  insertPlayerStmt.run(playerId, name, JSON.stringify(state), now);
  return { player_id: playerId, display_name: name };
}
function ensurePlayerState(playerId) {
  const row = getPlayerByIdStmt.get(playerId);
  if (!row) {
    throw new HttpError(404, "Player not found.");
  }
  const parsed = safeParseState(row.state_json, row.player_id, row.display_name);
  if (!parsed) {
    const now = Date.now();
    const state = createDefaultState(row.player_id, row.display_name, now);
    updatePlayerStmt.run(JSON.stringify(state), now, row.player_id);
    return state;
  }
  return parsed;
}
function getIdempotentState(playerId, clientActionId, actionType, payload) {
  const already = getActionStmt.get(playerId, clientActionId);
  if (!already) {
    return null;
  }
  if (actionType) {
    let previous;
    try {
      previous = JSON.parse(already.payload_json);
    } catch {
      throw new HttpError(409, "Stored action payload is invalid.");
    }
    if (already.action_type !== actionType || canonicalActionPayload(previous) !== canonicalActionPayload(payload))
      throw new HttpError(409, "Action ID already used with different content.");
    return ensurePlayerState(playerId);
  }
  if (already.result_state_json) {
    const parsed = safeParseState(already.result_state_json, playerId, "");
    if (parsed) {
      return parsed;
    }
  }
  return ensurePlayerState(playerId);
}
function canonicalActionPayload(value) {
  if (Array.isArray(value))
    return `[${value.map(canonicalActionPayload).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const obj = value;
    return `{${Object.keys(obj).sort().map((key) => `${JSON.stringify(key)}:${canonicalActionPayload(obj[key])}`).join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
function safeParseState(stateJson, playerId, displayName) {
  try {
    const parsed = JSON.parse(stateJson);
    if (typeof parsed != "object" || parsed == null) {
      return null;
    }
    const resolvedName = displayName || (typeof parsed.display_name == "string" ? parsed.display_name : "");
    const wallet = normalizeWallet(parsed.wallet);
    const lab = normalizeLab(parsed.lab);
    const world = normalizeWorld(parsed.world, Date.now());
    const researchFlags = normalizeResearchFlags(parsed.research_flags);
    return {
      ...parsed,
      player_id: playerId,
      state_revision: Number.isSafeInteger(parsed.state_revision) && parsed.state_revision >= 0 ? parsed.state_revision : 0,
      display_name: resolvedName,
      wallet,
      lab,
      world,
      research_flags: researchFlags,
      spell_progress: normalizeSpellProgress(parsed.spell_progress),
      item_progress: normalizeItemProgress(parsed.item_progress),
      homunculus_progress: normalizeHomunculusProgress(parsed.homunculus_progress),
      updated_at: Number(parsed.updated_at ?? Date.now())
    };
  } catch {
    return null;
  }
}
function createDefaultState(playerId, displayName, now, newAccount = false) {
  const wallet = normalizeWallet(newAccount ? { essence: 120, core: 5 } : {});
  const lab = normalizeLab({});
  const world = normalizeWorld({}, now);
  return {
    player_id: playerId,
    state_revision: 0,
    display_name: displayName,
    wallet,
    lab,
    world,
    research_flags: {},
    spell_progress: normalizeSpellProgress(null),
    item_progress: {},
    homunculus_progress: {},
    updated_at: now
  };
}
function applyAction(state, actionType, payload, clientActionId = "", debugBypass = false) {
  const now = Date.now();
  const next = {
    ...state,
    wallet: { ...state.wallet },
    research_flags: { ...state.research_flags },
    spell_progress: normalizeSpellProgress(state.spell_progress),
    item_progress: normalizeItemProgress(state.item_progress),
    homunculus_progress: normalizeHomunculusProgress(state.homunculus_progress),
    lab: {
      ...state.lab,
      buildings: { ...state.lab.buildings },
      runtime: cloneLabRuntime(state.lab.runtime)
    }
  };
  const runtime = ensureLabRuntime(next);
  cleanupLabRuntime(runtime, now);
  autoCompleteResearch(next, now);
  if (actionType == "UPGRADE_BUILDING") {
    return applyUpgrade(next, payload, debugBypass);
  }
  if (actionType === "HOM_UPGRADE" || actionType === "HOM_MUTATE") {
    const id = typeof payload?.homunculus_id === "string" ? payload.homunculus_id : "";
    if (!staticData.homunculusIds.has(id))
      return { state: next, error: "Unknown homunculus." };
    if ((next.lab.buildings.homunculus_vat?.level ?? 0) < 1)
      return { state: next, error: "Homunculus Vat is not constructed." };
    const current = next.homunculus_progress[id] ?? { level: 0 };
    let cost;
    if (actionType === "HOM_UPGRADE") {
      if (next.lab.hqLevel < 2 || current.level >= 10)
        return { state: next, error: "Homunculus upgrade unavailable." };
      cost = { essence: Math.trunc(getBalanceNumber("hom_upgrade_essence_base", 25) + current.level * getBalanceNumber("hom_upgrade_essence_per_level", 15)) };
      if (current.level >= 5)
        cost.core = 1;
    } else {
      if (current.level < 3 || typeof payload?.mutation_id !== "string" || !staticData.mutationIds.has(payload.mutation_id) || payload.mutation_id === current.mutation_id || (current.mutation_changed_at ?? 0) > 0 && now < current.mutation_changed_at + getBalanceNumber("hom_mutation_cooldown_seconds", 21600) * 1000)
        return { state: next, error: "Mutation unavailable." };
      cost = staticData.balance.hom_mutation_cost;
    }
    if (!cost || typeof cost !== "object" || Array.isArray(cost) || Object.keys(cost).some((id2) => !staticData.resources.has(id2)) || Object.values(cost).some((amount) => !Number.isSafeInteger(amount) || amount < 0))
      return { state: next, error: "Invalid homunculus cost configuration." };
    if (Object.entries(cost).some(([res, amount]) => (next.wallet[res] ?? 0) < amount))
      return { state: next, error: "Insufficient resources." };
    for (const [res, amount] of Object.entries(cost))
      next.wallet[res] = (next.wallet[res] ?? 0) - amount;
    next.homunculus_progress[id] = actionType === "HOM_UPGRADE" ? { ...current, level: current.level + 1 } : { ...current, mutation_id: payload.mutation_id, mutation_changed_at: now };
    return { state: next };
  }
  if (actionType == "FORGE_UPGRADE") {
    const id = typeof payload?.item_id === "string" ? payload.item_id : "";
    if (!staticData.itemIds.has(id))
      return { state: next, error: "Unknown item_id." };
    if ((next.lab.buildings.build_forge?.level ?? 0) < 1)
      return { state: next, error: "Build Forge is not constructed." };
    const current = next.item_progress[id] ?? { level: 0 };
    if (current.level >= 10)
      return { state: next, error: "Item level cap reached." };
    const cost = Math.max(0, Math.trunc(getBalanceNumber("forge_upgrade_essence_base", 20) + current.level * getBalanceNumber("forge_upgrade_essence_per_level", 10)));
    if ((next.wallet.essence ?? 0) < cost)
      return { state: next, error: "Insufficient essence." };
    next.wallet.essence -= cost;
    next.item_progress[id] = { ...current, level: current.level + 1 };
    return { state: next };
  }
  if (actionType === "FORGE_FUSE") {
    const id = typeof payload?.item_id === "string" ? payload.item_id : "";
    const donor = typeof payload?.donor_id === "string" ? payload.donor_id : "";
    if (!staticData.itemIds.has(id) || !staticData.itemIds.has(donor) || id === donor)
      return { state: next, error: "Invalid fusion weapons." };
    if ((next.lab.buildings.build_forge?.level ?? 0) < 1)
      return { state: next, error: "Build Forge is not constructed." };
    const current = next.item_progress[id] ?? { level: 0 };
    if (current.level < 3 || (next.item_progress[donor]?.level ?? 0) < 3)
      return { state: next, error: "Both weapons require level 3." };
    if (current.pending_reroll != null || current.fusion?.donor_id === donor)
      return { state: next, error: "Fusion unavailable." };
    const rarity = staticData.itemRarities[donor];
    const imprint = staticData.balance.forge_fusion_imprints?.[donor];
    const cost = staticData.balance[`forge_fusion_cost_${rarity}`];
    const effectIds = ["true_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "dot_true", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"];
    if (!["basic", "advanced"].includes(rarity) || !imprint || typeof imprint !== "object" || Array.isArray(imprint) || Object.entries(imprint).length !== 1 || Object.entries(imprint).some(([key, value]) => !effectIds.includes(key) || typeof value !== "number" || !Number.isFinite(value) || value <= 0) || !cost || typeof cost !== "object" || Array.isArray(cost) || Object.keys(cost).sort().join(",") !== "arcane_shard,core,essence" || Object.values(cost).some((value) => !Number.isSafeInteger(value) || value < 0))
      return { state: next, error: "Invalid fusion configuration." };
    if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < amount))
      return { state: next, error: "Insufficient resources." };
    for (const [resource, amount] of Object.entries(cost))
      next.wallet[resource] = (next.wallet[resource] ?? 0) - amount;
    next.item_progress[id] = { ...current, fusion: { donor_id: donor } };
    return { state: next };
  }
  if (["FORGE_SPECIALIZE", "FORGE_ALLOCATE_TRAIT", "FORGE_REROLL_TRAIT", "FORGE_CHOOSE_REROLL"].includes(actionType)) {
    const id = typeof payload?.item_id === "string" ? payload.item_id : "";
    if (!staticData.itemIds.has(id))
      return { state: next, error: "Unknown item_id." };
    const current = next.item_progress[id] ?? { level: 0 };
    const isSpecialize = actionType === "FORGE_SPECIALIZE";
    const isReroll = actionType === "FORGE_REROLL_TRAIT";
    const isChoose = actionType === "FORGE_CHOOSE_REROLL";
    if ((isSpecialize || isReroll) && (next.lab.buildings.build_forge?.level ?? 0) < 1)
      return { state: next, error: "Build Forge is not constructed." };
    const path = isSpecialize ? payload?.path : current.specialization;
    if (typeof path !== "string" || !["aggressive", "defensive", "technical"].includes(path))
      return { state: next, error: "Invalid specialization." };
    if (isSpecialize && (current.level < 1 || current.specialization != null))
      return { state: next, error: "Item cannot be specialized." };
    const pool = staticData.balance.forge_trait_pool?.[path];
    if (!pool || typeof pool !== "object" || Array.isArray(pool))
      return { state: next, error: "Invalid trait configuration." };
    const ids = Object.keys(pool);
    if (ids.length < 3 || ids.some((key) => typeof pool[key] !== "number" || !Number.isFinite(pool[key]) || pool[key] <= 0))
      return { state: next, error: "Invalid trait configuration." };
    const maxPoints = getBalanceNumber("forge_trait_max_points_per_slot", 4);
    if (!Number.isInteger(maxPoints) || maxPoints < 1)
      return { state: next, error: "Invalid trait configuration." };
    let traits = [];
    if (!isSpecialize) {
      if (!Array.isArray(current.traits) || current.traits.length !== 3)
        return { state: next, error: "Invalid item traits." };
      traits = current.traits.map((trait) => ({ ...trait }));
      if (traits.some((t) => !t || typeof t.id !== "string" || !ids.includes(t.id) || !Number.isInteger(t.points) || t.points < 0 || t.points > maxPoints) || new Set(traits.map((t) => t.id)).size !== 3 || traits.reduce((sum, t) => sum + t.points, 0) > current.level)
        return { state: next, error: "Invalid item traits." };
    }
    const slot = payload?.slot;
    if (!isSpecialize && (!Number.isInteger(slot) || slot < 0 || slot > 2))
      return { state: next, error: "Invalid trait slot." };
    if (!isSpecialize && !isChoose && current.pending_reroll != null)
      return { state: next, error: "Resolve the pending reroll first." };
    if (!isSpecialize && !isReroll && !isChoose && (traits[slot].points >= maxPoints || traits.reduce((sum, t) => sum + t.points, 0) >= current.level))
      return { state: next, error: "No available trait points." };
    const pending = current.pending_reroll;
    if (isChoose && (!pending || pending.slot !== slot || !Array.isArray(pending.options) || pending.options.length !== 3 || new Set(pending.options).size !== 3 || pending.options.some((option) => typeof option !== "string" || !ids.includes(option) || traits.some((t) => t.id === option)) || typeof payload?.trait_id !== "string" || !pending.options.includes(payload.trait_id)))
      return { state: next, error: "Invalid or stale reroll selection." };
    const chooseTrait = (candidates, slotIndex) => {
      const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["forge_trait_v1", state.player_id, id, slotIndex, clientActionId])).digest();
      return candidates[digest.readUInt32BE(0) % candidates.length];
    };
    if (isReroll && ids.filter((candidate) => !traits.some((t) => t.id === candidate)).length < 3)
      return { state: next, error: "Not enough alternative traits available." };
    if (isSpecialize || isReroll) {
      const configuredCost = staticData.balance[isSpecialize ? "forge_specialize_cost" : "forge_reroll_cost"];
      if (!configuredCost || typeof configuredCost !== "object" || Array.isArray(configuredCost))
        return { state: next, error: "Invalid forge cost configuration." };
      const cost = { essence: configuredCost.essence, core: configuredCost.core };
      if (isReroll && current.level >= 7)
        cost.arcane_shard = getBalanceNumber("forge_reroll_high_level_shard", 1);
      if (Object.values(cost).some((amount) => !Number.isSafeInteger(amount) || amount < 0))
        return { state: next, error: "Invalid forge cost configuration." };
      if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < amount))
        return { state: next, error: "Insufficient resources." };
      for (const [resource, amount] of Object.entries(cost))
        next.wallet[resource] = (next.wallet[resource] ?? 0) - amount;
    }
    if (isSpecialize) {
      for (let i = 0;i < 3; i++)
        traits.push({ id: chooseTrait(ids.filter((candidate) => !traits.some((t) => t.id === candidate)), i), points: 0 });
    } else if (isReroll) {
      const options = [];
      for (let i = 0;i < 3; i++) {
        const candidates = ids.filter((candidate) => !traits.some((t) => t.id === candidate) && !options.includes(candidate));
        const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["forge_reroll_offer_v1", state.player_id, id, slot, clientActionId, i])).digest();
        options.push(candidates[digest.readUInt32BE(0) % candidates.length]);
      }
      next.item_progress[id] = { ...current, specialization: path, traits, pending_reroll: { slot, options } };
      return { state: next };
    } else if (isChoose) {
      traits[slot] = { ...traits[slot], id: payload.trait_id };
      const { pending_reroll: _pending, ...remaining } = current;
      next.item_progress[id] = { ...remaining, specialization: path, traits };
      return { state: next };
    } else {
      traits[slot] = { ...traits[slot], points: traits[slot].points + 1 };
    }
    next.item_progress[id] = { ...current, specialization: path, traits };
    return { state: next };
  }
  if (actionType == "SET_BUILDING_ROUTE") {
    return applyRouteChange(next, payload);
  }
  if (actionType == "CLAIM_PRODUCTION") {
    return applyClaim(next, payload, now);
  }
  if (actionType === "NPC_TRADE") {
    if (next.lab.hqLevel < 2 || (next.lab.buildings.trade_hall?.level ?? 0) < 1)
      return { state: next, error: "Trade Hall unavailable." };
    const listing = npcTradeOffers(runtime, now);
    const offer = listing.offers.find((entry) => entry.id === payload?.offer_id && entry.period_key === payload?.period_key);
    if (!offer || offer.remaining <= 0)
      return { state: next, error: "NPC offer unavailable or expired." };
    if (Object.entries(offer.pay).some(([id, amount]) => (next.wallet[id] ?? 0) < amount))
      return { state: next, error: "Insufficient resources." };
    for (const [id, amount] of Object.entries(offer.pay))
      next.wallet[id] = (next.wallet[id] ?? 0) - amount;
    applyWalletGrant(next.wallet, offer.receive);
    const counts = runtime.npc_trade ?? { day_key: listing.day_key, week_key: listing.week_key, daily_uses: {}, weekly_uses: {} };
    if (counts.day_key !== listing.day_key) {
      counts.day_key = listing.day_key;
      counts.daily_uses = {};
    }
    if (counts.week_key !== listing.week_key) {
      counts.week_key = listing.week_key;
      counts.weekly_uses = {};
    }
    const uses = offer.period === "daily" ? counts.daily_uses : counts.weekly_uses;
    uses[offer.id] = (uses[offer.id] ?? 0) + 1;
    runtime.npc_trade = counts;
    return { state: next };
  }
  if (actionType === "SYNC_START") {
    if (next.lab.hqLevel < 4 || (next.lab.buildings.sync_nexus?.level ?? 0) < 1)
      return { state: next, error: "Sync Nexus unavailable." };
    if (runtime.sync_project)
      return { state: next, error: "Sync project already active." };
    const duration = getBalanceNumber("sync_npc_duration_seconds", 28800);
    if (!Number.isSafeInteger(duration) || duration <= 0)
      return { state: next, error: "Invalid sync duration." };
    runtime.sync_project = { project_id: "calibration", partner_kind: "npc", partner_id: "echo", started_at: now, completes_at: now + duration * 1000 };
    return { state: next };
  }
  if (actionType === "SYNC_CLAIM") {
    const project = runtime.sync_project;
    if (!project || now < project.completes_at)
      return { state: next, error: "Sync project is not ready." };
    const reward = staticData.balance.sync_npc_reward;
    if (!reward || typeof reward !== "object" || Array.isArray(reward) || Object.entries(reward).some(([id, amount]) => !["essence", "core", "arcane_shard", "time_crystal"].includes(id) || !staticData.resources.has(id) || !Number.isSafeInteger(amount) || amount < 0))
      return { state: next, error: "Invalid sync reward configuration." };
    applyWalletGrant(next.wallet, reward);
    delete runtime.sync_project;
    return { state: next };
  }
  if (actionType === "ANOMALY_RESOLVE") {
    const choice = payload?.choice;
    const level = next.lab.buildings.anomaly_containment?.level ?? 0;
    if (!["seal", "investigate"].includes(choice) || level < 1 || next.lab.hqLevel < (HQ_RULES.anomaly_containment?.unlock ?? 5))
      return { state: next, error: "Anomaly unavailable." };
    if ((runtime.anomaly?.next_at ?? 0) > now)
      return { state: next, error: "Anomaly on cooldown." };
    const validReward2 = (reward2) => !!reward2 && typeof reward2 === "object" && !Array.isArray(reward2) && Object.entries(reward2).every(([id, amount]) => ["essence", "core", "arcane_shard", "time_crystal"].includes(id) && staticData.resources.has(id) && Number.isSafeInteger(amount) && amount >= 0);
    let reward;
    if (choice === "seal") {
      reward = staticData.balance.anomaly_seal_reward;
      if (!validReward2(reward))
        return { state: next, error: "Invalid anomaly reward configuration." };
    } else {
      const outcomes = staticData.balance.anomaly_investigate_outcomes;
      if (!Array.isArray(outcomes) || !outcomes.length || outcomes.some((entry) => !entry || typeof entry.weight !== "number" || !Number.isFinite(entry.weight) || entry.weight < 0 || !validReward2(entry.reward)) || Math.abs(outcomes.reduce((sum, entry) => sum + entry.weight, 0) - 1) > 0.000001)
        return { state: next, error: "Invalid anomaly outcome configuration." };
      const digest = createHmac("sha256", EXPERIMENT_SECRET).update(JSON.stringify(["anomaly_resolve_v1", state.player_id, clientActionId])).digest();
      const roll = digest.readUInt32BE(0) / 4294967296;
      let cumulative = 0;
      reward = outcomes[outcomes.length - 1].reward;
      for (const outcome of outcomes) {
        cumulative += outcome.weight;
        if (roll < cumulative) {
          reward = outcome.reward;
          break;
        }
      }
    }
    const base = getBalanceNumber("anomaly_cooldown_base_seconds", 28800);
    const reduction = getBalanceNumber("anomaly_cooldown_reduction_per_level", 900);
    if (base <= 0 || reduction < 0 || base - (level - 1) * reduction <= 0)
      return { state: next, error: "Invalid anomaly cooldown configuration." };
    applyWalletGrant(next.wallet, reward);
    runtime.anomaly = { next_at: now + (base - (level - 1) * reduction) * 1000, last_choice: choice, last_reward: { ...reward }, last_at: now };
    return { state: next };
  }
  if (actionType === "SET_HQ_DIRECTIVE") {
    const id = payload?.directive;
    if (!["production", "research", "experimentation"].includes(id) || next.lab.hqLevel < 1)
      return { state: next, error: "Invalid HQ directive." };
    if ((runtime.directive?.ends_at ?? 0) > now)
      return { state: next, error: "HQ directive is active." };
    const reactor = ensureBuildingState(next, "essence_reactor");
    const storage = ensureBuildingState(next, "storage_vault");
    if (reactor.level > 0)
      tickProduction(reactor, now, reactor.level, reactor.route || "stable", storage.route || "", next.lab.hqPath, runtime);
    runtime.directive = { id, starts_at: now, ends_at: now + Math.max(1, getBalanceNumber("hq_directive_duration_seconds", 86400)) * 1000 };
    return { state: next };
  }
  if (actionType === "REACTOR_OVERCHARGE") {
    const threshold = Math.max(1, Math.trunc(getBalanceNumber("reactor_overcharge_threshold", 300)));
    const charge = runtime.reactor_overcharge ?? { progress: 0, last_used_at: 0 };
    if ((next.lab.buildings.essence_reactor?.level ?? 0) < 1 || charge.progress < threshold || charge.last_used_at > 0 && now < charge.last_used_at + getBalanceNumber("reactor_overcharge_cooldown_seconds", 10800) * 1000)
      return { state: next, error: "Overcharge is not ready." };
    const reward = staticData.balance.reactor_overcharge_reward;
    if (!reward || typeof reward !== "object" || Array.isArray(reward) || Object.entries(reward).some(([id, amount]) => !staticData.resources.has(id) || !Number.isSafeInteger(amount) || amount < 0))
      return { state: next, error: "Invalid overcharge reward." };
    applyWalletGrant(next.wallet, reward);
    runtime.reactor_overcharge = { progress: 0, last_used_at: now };
    return { state: next };
  }
  if (actionType == "START_EXPERIMENT") {
    return applyStartExperiment(next, payload, clientActionId, now);
  }
  if (actionType == "START_RESEARCH") {
    return applyStartResearch(next, payload, now);
  }
  if (actionType === "QUEUE_RESEARCH") {
    const id = typeof payload?.research_id === "string" ? payload.research_id.trim() : "";
    const node = staticData.research[id];
    const activeId = runtime.research.active_id ?? "";
    const active = staticData.research[activeId];
    if (!node || !active || id === activeId || runtime.research.queued_id || next.research_flags[node.flag_id])
      return { state: next, error: "Research queue unavailable." };
    if (next.lab.hqLevel < (HQ_RULES.arcane_archives?.unlock ?? 3) || (next.lab.buildings.arcane_archives?.level ?? 0) < 1)
      return { state: next, error: "Arcane Archives not built or locked." };
    if (node.requires.some((req) => !next.research_flags[req] && req !== active.flag_id))
      return { state: next, error: "Research requirements not met." };
    const fee = getBalanceNumber("archive_queue_fee_essence", 10);
    if (!Number.isSafeInteger(fee) || fee < 0)
      return { state: next, error: "Invalid queue fee." };
    const cost = { essence: fee };
    for (const [resource, amount] of Object.entries(node.cost)) {
      if (!staticData.resources.has(resource) || !Number.isSafeInteger(amount) || amount < 0)
        return { state: next, error: "Invalid research cost." };
      cost[resource] = (cost[resource] ?? 0) + amount;
    }
    if (Object.entries(cost).some(([resource, amount]) => (next.wallet[resource] ?? 0) < amount))
      return { state: next, error: "Insufficient resources." };
    for (const [resource, amount] of Object.entries(cost))
      next.wallet[resource] = (next.wallet[resource] ?? 0) - amount;
    runtime.research.queued_id = id;
    return { state: next };
  }
  if (actionType == "START_SPELL_RESEARCH") {
    const error = startSpellResearch(next, payload, now, staticData.resources, staticData.balance, isBoostActive(runtime, "fast_spells", now) ? experimentEffect("fast_spells", "spell_time_mult", 0.85) : 1);
    return error ? { state: next, error } : { state: next };
  }
  if (actionType == "SET_SPELL_LOADOUT") {
    const error = setSpellLoadout(next, payload);
    return error ? { state: next, error } : { state: next };
  }
  if (actionType == "CLAIM_SPELL_RESEARCH") {
    const error = claimSpellResearch(next, payload, now);
    return error ? { state: next, error } : { state: next };
  }
  if (actionType == "CLAIM_RESEARCH" || actionType == "COMPLETE_RESEARCH") {
    return applyClaimResearch(next, payload, now);
  }
  return { state: next, error: "Unknown action_type." };
}
function broadcast(message) {
  const payload = JSON.stringify(message);
  for (const socket of sockets) {
    socket.send(payload);
  }
}
async function maybeRunExternalExamples() {
  const runPostgres = Bun.env.PG_EXAMPLE == "1" || Bun.env.POSTGRES_EXAMPLE == "1";
  const runRedis = Bun.env.REDIS_EXAMPLE == "1";
  if (runPostgres) {
    await postgresExample();
  }
  if (runRedis) {
    await redisExample();
  }
}
async function startServer() {
  maybeRunExternalExamples();
  const server = Bun.serve({
    hostname: config.host,
    port: config.port,
    fetch: async (req, server2) => {
      const ctx = {
        requestId: getRequestId(req),
        rateLimitBypass: false,
        startAt: Date.now(),
        ip: getClientIp(req),
        path: new URL(req.url).pathname
      };
      const corsHeaders = buildCorsHeaders(req);
      if (req.method == "OPTIONS") {
        const res = new Response(null, { status: 204 });
        const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
        recordRequest(finalRes.status, Date.now() - ctx.startAt);
        return finalRes;
      }
      try {
        const res = await (async () => {
          const url = new URL(req.url);
          if (url.pathname == "/ws") {
            const address = server2.requestIP(req)?.address;
            if (IS_PRODUCTION || !["127.0.0.1", "::1", "::ffff:127.0.0.1"].includes(address ?? "")) {
              return jsonResponse({ error: "WebSocket unavailable." }, 403);
            }
            const upgraded = server2.upgrade(req, { data: { ip: getClientIp(req) } });
            if (upgraded) {
              return;
            }
            return jsonResponse({ error: "Upgrade required" }, 426);
          }
          if (req.method == "POST" && url.pathname == "/auth/dev_login") {
            const address = server2.requestIP(req)?.address;
            if (!developmentLoginAllowed(address, req.headers.get("origin"))) {
              throw new HttpError(403, "Development login unavailable.");
            }
            await applyRateLimit(ctx, {
              keyPrefix: "rl:login",
              windowSeconds: getEnvNumber("LOGIN_RATE_LIMIT_WINDOW_SECONDS", 600),
              max: getEnvNumber("LOGIN_RATE_LIMIT_MAX", 10),
              keyBy: "ip"
            });
            const body = await readJson(req, config.maxBodyBytes);
            const name = typeof body?.name == "string" ? body.name.trim() : "";
            if (!name || name.length > 64) {
              logWarn("Auth invalid dev_login name", { name: body?.name });
              throw new HttpError(400, "Missing or invalid name.");
            }
            const player = findOrCreatePlayer(name);
            const token = await issueToken(player.player_id);
            const email = normalizeLoginEmail(name);
            await upsertUser({ id: player.player_id, email, displayName: name });
            return loginResponse(player.player_id, token);
          }
          if (req.method == "POST" && url.pathname == "/v1/auth/login") {
            const address = server2.requestIP(req)?.address;
            if (!developmentLoginAllowed(address, req.headers.get("origin"))) {
              throw new HttpError(403, "Development login unavailable.");
            }
            await applyRateLimit(ctx, {
              keyPrefix: "rl:login",
              windowSeconds: getEnvNumber("LOGIN_RATE_LIMIT_WINDOW_SECONDS", 600),
              max: getEnvNumber("LOGIN_RATE_LIMIT_MAX", 10),
              keyBy: "ip"
            });
            const body = await readJson(req, config.maxBodyBytes);
            const emailRaw = typeof body?.email == "string" ? body.email.trim() : "";
            const nameRaw = typeof body?.name == "string" ? body.name.trim() : "";
            const displayName = nameRaw || (emailRaw ? emailRaw.split("@")[0] : "");
            if (!displayName) {
              throw new HttpError(400, "Missing email or name.");
            }
            const player = findOrCreatePlayer(displayName);
            const email = emailRaw ? emailRaw.toLowerCase() : normalizeLoginEmail(displayName);
            await upsertUser({ id: player.player_id, email, displayName });
            if (await isUserDisabled(player.player_id)) {
              throw new HttpError(403, "User disabled.");
            }
            const fingerprint = typeof body?.fingerprint == "string" ? body.fingerprint : undefined;
            const pair = await issueTokenPair(player.player_id, ACCESS_TTL_MS, REFRESH_TTL_MS, fingerprint);
            return tokenPairResponse(pair.accessToken, pair.refreshToken);
          }
          if (req.method == "POST" && url.pathname == "/v1/auth/refresh") {
            await applyRateLimit(ctx, {
              keyPrefix: "rl:refresh",
              windowSeconds: getEnvNumber("REFRESH_RATE_LIMIT_WINDOW_SECONDS", 600),
              max: getEnvNumber("REFRESH_RATE_LIMIT_MAX", 20),
              keyBy: "ip"
            });
            const body = await readJson(req, config.maxBodyBytes);
            const refreshToken = typeof body?.refresh_token == "string" ? body.refresh_token.trim() : "";
            if (!refreshToken) {
              throw new HttpError(400, "Missing refresh_token.");
            }
            const fingerprint = typeof body?.fingerprint == "string" ? body.fingerprint : undefined;
            const rotated = await rotateRefreshToken(refreshToken, REFRESH_TTL_MS, fingerprint);
            if (!rotated) {
              throw new HttpError(401, "Invalid refresh token.");
            }
            if (await isUserDisabled(rotated.record.userId)) {
              throw new HttpError(403, "User disabled.");
            }
            const accessToken = await issueAccessToken(rotated.record.userId, ACCESS_TTL_MS);
            return tokenPairResponse(accessToken, rotated.refreshToken);
          }
          if (req.method == "POST" && url.pathname == "/v1/auth/logout") {
            const body = await readJson(req, config.maxBodyBytes);
            const refreshToken = typeof body?.refresh_token == "string" ? body.refresh_token.trim() : "";
            if (refreshToken) {
              await revokeRefreshToken(refreshToken);
            }
            const accessToken = extractToken(req);
            if (accessToken) {
              await revokeAccessToken(accessToken);
            }
            return jsonResponse({ ok: true, server_time_unix_ms: Date.now() });
          }
          if (req.method == "POST" && url.pathname == "/auth/logout") {
            const token = extractToken(req);
            if (!token) {
              throw new HttpError(401, "Missing auth token.");
            }
            await revokeSession(token);
            await revokeAccessToken(token);
            return jsonResponse({ ok: true, server_time_unix_ms: Date.now() });
          }
          if (url.pathname == "/player/state") {
            const playerId = await requireAuth(req, ctx);
            return db.transaction(() => {
              const state = ensurePlayerState(playerId);
              const now = Date.now();
              const runtime = ensureLabRuntime(state);
              let changed = cleanupLabRuntime(runtime, now);
              changed = autoCompleteResearch(state, now) || changed;
              changed = refreshWorldPlayer(state.world, now) || changed;
              if (changed) {
                state.updated_at = now;
                updatePlayerStmt.run(JSON.stringify(state), now, playerId);
              }
              return stateResponse(state);
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/combat/rewards/claim") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, { keyPrefix: "rl:action", windowSeconds: EXPENSIVE_RATE_WINDOW, max: EXPENSIVE_RATE_MAX, keyBy: "user", userId: playerId });
            const body = await readJson(req, config.maxBodyBytes);
            const matchId = typeof body?.match_id === "string" ? body.match_id.trim().toLowerCase() : "";
            const actionId = typeof body?.client_action_id === "string" ? body.client_action_id.trim().toLowerCase() : "";
            const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
            if (!uuid.test(matchId) || !uuid.test(actionId))
              throw new HttpError(400, "match_id and client_action_id must be UUIDs.");
            const payload = { match_id: matchId };
            const result = claimVerifiedCombatReward(db, matchId, playerId, (reward, duplicate) => {
              const prior = getIdempotentState(playerId, actionId, "COMBAT_REWARD_CLAIM", payload);
              if (prior && !duplicate)
                throw new HttpError(409, "Inconsistent combat reward action.");
              const state = prior ?? ensurePlayerState(playerId);
              const now = Date.now();
              if (!duplicate && reward) {
                if (!isValidResourceId(reward.resource_id))
                  throw new HttpError(400, "Unknown reward resource.");
                const before = { ...state.wallet };
                applyWalletGrant(state.wallet, { [reward.resource_id]: reward.amount });
                assertWalletInvariant(state.wallet);
                state.updated_at = now;
                updatePlayerStmt.run(JSON.stringify(state), now, playerId);
                auditWalletMutation(playerId, computeWalletDelta(before, state.wallet), "COMBAT_REWARD_CLAIM", matchId, now);
              }
              if (!prior)
                insertActionStmt.run(playerId, actionId, "COMBAT_REWARD_CLAIM", JSON.stringify(payload), JSON.stringify(state), now);
              return state;
            });
            return stateResponseExtra(result.state, { match_id: matchId, reward: result.reward, duplicate: result.duplicate });
          }
          if (req.method == "POST" && url.pathname == "/player/action") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:action",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            const actionType = typeof body?.action_type == "string" ? body.action_type.trim() : "";
            let payload = body?.payload ?? {};
            const clientTimeRaw = body?.client_time_unix_ms;
            const clientTime = typeof clientTimeRaw == "number" ? clientTimeRaw : Number(clientTimeRaw ?? 0);
            if (!clientActionId || !actionType || clientActionId.length > 64) {
              console.warn("Action: missing client_action_id/action_type", body);
              throw new HttpError(400, "Missing client_action_id or action_type.");
            }
            if (!Number.isFinite(clientTime)) {
              console.warn("Action: missing or invalid client_time_unix_ms", clientTimeRaw);
            }
            if (!payload || typeof payload != "object") {
              console.warn("Action: payload must be an object");
              payload = {};
            }
            const debugBypass = isDebugBypass(req);
            const result = db.transaction(() => {
              const already = getActionStmt.get(playerId, clientActionId);
              if (already) {
                let previousPayload;
                try {
                  previousPayload = JSON.parse(already.payload_json);
                } catch {
                  throw new HttpError(409, "Cannot verify previous action payload.");
                }
                if (already.action_type !== actionType || canonicalActionPayload(previousPayload) !== canonicalActionPayload(payload))
                  throw new HttpError(409, "Action ID already used with different content.");
                return { state: ensurePlayerState(playerId), duplicate: true };
              }
              const state = ensurePlayerState(playerId);
              const updated = applyAction(state, actionType, payload, clientActionId, debugBypass);
              if (updated.error)
                throw new HttpError(400, updated.error);
              const walletDelta = computeWalletDelta(state.wallet, updated.state.wallet);
              checkSuspiciousDelta(playerId, walletDelta, actionType, clientActionId);
              const invariantError = getWalletInvariantError(updated.state.wallet);
              if (invariantError)
                throw new HttpError(400, invariantError);
              const now = Date.now();
              updated.state.updated_at = now;
              assertWalletInvariant(updated.state.wallet);
              updatePlayerStmt.run(JSON.stringify(updated.state), now, playerId);
              insertActionStmt.run(playerId, clientActionId, actionType, JSON.stringify(payload ?? {}), JSON.stringify(updated.state), now);
              auditWalletMutation(playerId, walletDelta, actionType, clientActionId, now);
              return { state: updated.state, duplicate: false };
            }).immediate();
            if (result.duplicate)
              return stateResponseExtra(result.state, { duplicate: true });
            enqueueJob("audit_snapshot", {
              player_id: playerId,
              action_type: actionType,
              at: Date.now()
            });
            broadcast({ type: "player_action", player_id: playerId, action_type: actionType });
            return stateResponse(result.state);
          }
          if (req.method == "GET" && url.pathname == "/market/orders") {
            const resourceIdRaw = url.searchParams.get("resource_id");
            const typeRaw = url.searchParams.get("type");
            const statusRaw = url.searchParams.get("status");
            const sellerRaw = url.searchParams.get("seller_id");
            const resourceId = resourceIdRaw ? resourceIdRaw.trim() : "";
            if (resourceId && !isValidResourceId(resourceId)) {
              console.warn("Market: invalid resource_id", resourceId);
              throw new HttpError(400, "Unknown resource_id.");
            }
            let type = typeRaw ? typeRaw.trim().toUpperCase() : "";
            if (type && type != MARKET_TYPE_SELL && type != MARKET_TYPE_BUY) {
              console.warn("Market: invalid type", typeRaw);
              throw new HttpError(400, "Invalid order type.");
            }
            let status = statusRaw ? statusRaw.trim().toUpperCase() : MARKET_STATUS_OPEN;
            if (status && status != MARKET_STATUS_OPEN && status != MARKET_STATUS_FILLED && status != MARKET_STATUS_CANCELED) {
              console.warn("Market: invalid status", statusRaw);
              throw new HttpError(400, "Invalid status.");
            }
            const sellerId = sellerRaw ? sellerRaw.trim() : "";
            const resourceParam = resourceId || null;
            const typeParam = type || null;
            const statusParam = status || null;
            const sellerParam = sellerId || null;
            const rows = listOrdersStmt.all(resourceParam, resourceParam, typeParam, typeParam, statusParam, statusParam, sellerParam, sellerParam, MARKET_LIST_LIMIT);
            const orders = rows.map((row) => {
              const amount = clampAmount(row.amount);
              const remaining = getOrderRemaining(String(row.order_id), amount);
              return {
                order_id: row.order_id,
                seller_id: row.seller_id,
                type: row.type,
                resource_id: row.resource_id,
                amount,
                remaining,
                price_resource_id: row.price_resource_id,
                price_amount: clampAmount(row.price_amount),
                fee_bps: clampInt(row.fee_bps, 0, 1e4),
                status: row.status,
                created_at: row.created_at
              };
            });
            return jsonResponse({ ok: true, orders });
          }
          if (req.method == "POST" && url.pathname == "/market/order") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:market",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Market: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const stored = getIdempotentState(playerId, clientActionId, "MARKET_ORDER", body);
              const orderId = makeOrderId(playerId, clientActionId);
              if (stored) {
                return stateResponseExtra(stored, { order_id: orderId });
              }
              const existingOrder = getOrderStmt.get(orderId);
              if (existingOrder) {
                const current = ensurePlayerState(playerId);
                return stateResponseExtra(current, { order_id: orderId });
              }
              let type = typeof body?.type == "string" && body.type.trim() != "" ? body.type.trim().toUpperCase() : MARKET_TYPE_SELL;
              if (type != MARKET_TYPE_SELL) {
                console.warn("Market: unsupported order type", type);
                throw new HttpError(400, "Only SELL orders are supported.");
              }
              const resourceId = typeof body?.resource_id == "string" ? body.resource_id.trim() : "";
              if (!resourceId || !isValidResourceId(resourceId)) {
                console.warn("Market: invalid resource_id", resourceId);
                throw new HttpError(400, "Unknown resource_id.");
              }
              let priceResourceId = typeof body?.price_resource_id == "string" ? body.price_resource_id.trim() : "";
              if (!priceResourceId) {
                priceResourceId = "essence";
              }
              if (!isValidResourceId(priceResourceId)) {
                console.warn("Market: invalid price_resource_id", priceResourceId);
                throw new HttpError(400, "Unknown price_resource_id.");
              }
              const amount = clampInt(body?.amount ?? 0, 0, MARKET_MAX_AMOUNT);
              if (amount <= 0 || amount > MARKET_MAX_AMOUNT) {
                console.warn("Market: invalid amount", body?.amount);
                throw new HttpError(400, "Invalid amount.");
              }
              const priceAmount = clampInt(body?.price_amount ?? 0, 0, MARKET_MAX_PRICE);
              if (priceAmount <= 0 || priceAmount > MARKET_MAX_PRICE) {
                console.warn("Market: invalid price_amount", body?.price_amount);
                throw new HttpError(400, "Invalid price_amount.");
              }
              const feeBps = getMarketFeeBps();
              if (isSuspiciousAmount(amount) || isSuspiciousAmount(priceAmount) || isSuspiciousAmount(amount * priceAmount)) {
                logSuspiciousAction(playerId, { [resourceId]: -amount }, "MARKET_ORDER", orderId);
                throw new HttpError(400, "Suspicious order amount.");
              }
              const now = Date.now();
              let state = null;
              db.transaction(() => {
                state = ensurePlayerState(playerId);
                const beforeWallet = cloneWallet(state.wallet);
                const available = clampAmount(state.wallet[resourceId] ?? 0);
                if (available < amount) {
                  throw new HttpError(400, "Insufficient resources.");
                }
                state.wallet[resourceId] = available - amount;
                addEscrow(playerId, resourceId, amount);
                insertOrderStmt.run(orderId, playerId, type, resourceId, amount, priceResourceId, priceAmount, feeBps, MARKET_STATUS_OPEN, now);
                assertWalletInvariant(state.wallet);
                state.updated_at = now;
                updatePlayerStmt.run(JSON.stringify(state), now, playerId);
                insertActionStmt.run(playerId, clientActionId, "MARKET_ORDER", JSON.stringify(body ?? {}), JSON.stringify(state), now);
                const delta = computeWalletDelta(beforeWallet, state.wallet);
                auditWalletMutation(playerId, delta, "MARKET_ORDER", orderId, now);
              })();
              if (!state) {
                throw new HttpError(500, "Failed to resolve seller state.");
              }
              return stateResponseExtra(state, { order_id: orderId });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/market/cancel") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:market",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Market: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const stored = getIdempotentState(playerId, clientActionId, "MARKET_CANCEL", body);
              if (stored) {
                return stateResponse(stored);
              }
              const orderId = typeof body?.order_id == "string" ? body.order_id.trim() : "";
              if (!orderId) {
                console.warn("Market: missing order_id", body);
                throw new HttpError(400, "Missing order_id.");
              }
              const order = getOrderStmt.get(orderId);
              if (!order) {
                throw new HttpError(404, "Order not found.");
              }
              if (order.seller_id != playerId) {
                throw new HttpError(403, "Cannot cancel another seller's order.");
              }
              if (String(order.status).toUpperCase() != MARKET_STATUS_OPEN) {
                throw new HttpError(400, "Order is not open.");
              }
              const totalAmount = clampAmount(order.amount);
              const now = Date.now();
              let state = null;
              db.transaction(() => {
                state = ensurePlayerState(playerId);
                const beforeWallet = cloneWallet(state.wallet);
                updateOrderStatusStmt.run(MARKET_STATUS_CANCELED, orderId);
                const remaining = getOrderRemaining(orderId, totalAmount);
                if (remaining > 0) {
                  if (!subtractEscrow(playerId, order.resource_id, remaining)) {
                    throw new HttpError(400, "Escrow mismatch.");
                  }
                  state.wallet[order.resource_id] = clampAmount(state.wallet[order.resource_id] ?? 0) + remaining;
                }
                assertWalletInvariant(state.wallet);
                state.updated_at = now;
                updatePlayerStmt.run(JSON.stringify(state), now, playerId);
                insertActionStmt.run(playerId, clientActionId, "MARKET_CANCEL", JSON.stringify(body ?? {}), JSON.stringify(state), now);
                const delta = computeWalletDelta(beforeWallet, state.wallet);
                auditWalletMutation(playerId, delta, "MARKET_CANCEL", orderId, now);
              })();
              if (!state) {
                throw new HttpError(500, "Failed to resolve seller state.");
              }
              return stateResponse(state);
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/market/buy") {
            const buyerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:market",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: buyerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Market: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const stored = getIdempotentState(buyerId, clientActionId, "MARKET_BUY", body);
              if (stored) {
                return stateResponse(stored);
              }
              const orderId = typeof body?.order_id == "string" ? body.order_id.trim() : "";
              if (!orderId) {
                console.warn("Market: missing order_id", body);
                throw new HttpError(400, "Missing order_id.");
              }
              const requestedAmount = clampInt(body?.amount ?? 0, 0, MARKET_MAX_AMOUNT);
              if (requestedAmount <= 0 || requestedAmount > MARKET_MAX_AMOUNT) {
                console.warn("Market: invalid buy amount", body?.amount);
                throw new HttpError(400, "Invalid amount.");
              }
              const previewOrder = getOrderStmt.get(orderId);
              if (!previewOrder) {
                throw new HttpError(404, "Order not found.");
              }
              const previewUnitPrice = clampInt(previewOrder.price_amount ?? 0, 0, MARKET_MAX_PRICE);
              rejectSuspiciousMarketBuy(buyerId, orderId, String(previewOrder.resource_id || ""), String(previewOrder.price_resource_id || "essence"), requestedAmount, previewUnitPrice);
              let buyerState = null;
              let sellerState = null;
              const now = Date.now();
              db.transaction(() => {
                const order = getOrderStmt.get(orderId);
                if (!order) {
                  throw new HttpError(404, "Order not found.");
                }
                if (String(order.status).toUpperCase() != MARKET_STATUS_OPEN) {
                  throw new HttpError(400, "Order is not open.");
                }
                if (String(order.type).toUpperCase() != MARKET_TYPE_SELL) {
                  throw new HttpError(400, "Only SELL orders are supported.");
                }
                if (order.seller_id == buyerId) {
                  throw new HttpError(400, "Cannot buy your own order.");
                }
                const resourceId = String(order.resource_id);
                if (!isValidResourceId(resourceId)) {
                  throw new HttpError(400, "Unknown resource_id.");
                }
                const priceResourceId = String(order.price_resource_id || "essence");
                if (!isValidResourceId(priceResourceId)) {
                  throw new HttpError(400, "Unknown price_resource_id.");
                }
                const totalAmount = clampAmount(order.amount);
                const remaining = getOrderRemaining(orderId, totalAmount);
                if (remaining <= 0) {
                  updateOrderStatusStmt.run(MARKET_STATUS_FILLED, orderId);
                  throw new HttpError(400, "Order already filled.");
                }
                const fillAmount = Math.min(remaining, requestedAmount);
                if (fillAmount <= 0) {
                  throw new HttpError(400, "Invalid amount.");
                }
                const unitPrice = clampInt(order.price_amount ?? 0, 0, MARKET_MAX_PRICE);
                if (unitPrice <= 0) {
                  throw new HttpError(400, "Invalid price.");
                }
                const totalPrice = unitPrice * fillAmount;
                if (totalPrice <= 0 || totalPrice > MARKET_MAX_PRICE * MARKET_MAX_AMOUNT) {
                  throw new HttpError(400, "Invalid total price.");
                }
                const feeBps = clampInt(order.fee_bps ?? 0, 0, 1e4);
                const fee = Math.floor(totalPrice * feeBps / 1e4);
                buyerState = ensurePlayerState(buyerId);
                sellerState = ensurePlayerState(order.seller_id);
                const beforeBuyer = cloneWallet(buyerState.wallet);
                const beforeSeller = cloneWallet(sellerState.wallet);
                const buyerWallet = buyerState.wallet;
                const sellerWallet = sellerState.wallet;
                if (clampAmount(buyerWallet[priceResourceId] ?? 0) < totalPrice) {
                  throw new HttpError(400, "Insufficient funds.");
                }
                buyerWallet[priceResourceId] = clampAmount(buyerWallet[priceResourceId] ?? 0) - totalPrice;
                applyWalletGrant(buyerWallet, { [resourceId]: fillAmount });
                const sellerCredit = Math.max(0, totalPrice - fee);
                sellerWallet[priceResourceId] = clampAmount(sellerWallet[priceResourceId] ?? 0) + sellerCredit;
                if (!subtractEscrow(order.seller_id, resourceId, fillAmount)) {
                  throw new HttpError(400, "Escrow mismatch.");
                }
                const fillId = crypto.randomUUID();
                insertFillStmt.run(fillId, orderId, buyerId, fillAmount, totalPrice, fee, now);
                if (fillAmount >= remaining) {
                  updateOrderStatusStmt.run(MARKET_STATUS_FILLED, orderId);
                }
                assertWalletInvariant(buyerWallet);
                assertWalletInvariant(sellerWallet);
                buyerState.updated_at = now;
                sellerState.updated_at = now;
                updatePlayerStmt.run(JSON.stringify(buyerState), now, buyerId);
                updatePlayerStmt.run(JSON.stringify(sellerState), now, order.seller_id);
                insertActionStmt.run(buyerId, clientActionId, "MARKET_BUY", JSON.stringify(body ?? {}), JSON.stringify(buyerState), now);
                const buyerDelta = computeWalletDelta(beforeBuyer, buyerWallet);
                const sellerDelta = computeWalletDelta(beforeSeller, sellerWallet);
                auditWalletMutation(buyerId, buyerDelta, "MARKET_BUY_BUYER", orderId, now);
                auditWalletMutation(order.seller_id, sellerDelta, "MARKET_BUY_SELLER", orderId, now);
              })();
              if (!buyerState) {
                throw new HttpError(500, "Failed to resolve buyer state.");
              }
              return stateResponse(buyerState);
            }).immediate();
          }
          if (req.method == "GET" && url.pathname == "/trade/npc/offers") {
            const playerId = await requireAuth(req, ctx);
            const now = Date.now();
            return jsonResponse({ ok: true, server_time_unix_ms: now, ...npcTradeOffers(ensureLabRuntime(ensurePlayerState(playerId)), now) });
          }
          if (req.method == "GET" && url.pathname == "/trade/jobs") {
            const outputResourceRaw = url.searchParams.get("output_resource_id");
            const statusRaw = url.searchParams.get("status");
            const outputResource = outputResourceRaw ? outputResourceRaw.trim() : "";
            if (outputResource && !isValidResourceId(outputResource)) {
              console.warn("Trade: invalid output_resource_id", outputResource);
              throw new HttpError(400, "Unknown output_resource_id.");
            }
            let status = statusRaw ? statusRaw.trim().toUpperCase() : TRADE_JOB_STATUS_OPEN;
            if (status && status != TRADE_JOB_STATUS_OPEN && status != TRADE_JOB_STATUS_CLOSED) {
              console.warn("Trade: invalid status", statusRaw);
              throw new HttpError(400, "Invalid status.");
            }
            const outputParam = outputResource || null;
            const statusParam = status || null;
            const rows = listTradeJobsStmt.all(outputParam, outputParam, statusParam, statusParam, TRADE_LIST_LIMIT);
            const jobs = rows.map((row) => {
              const pendingRow = countTradeRunsStmt.get(row.job_id, TRADE_RUN_STATUS_PENDING);
              const pending = pendingRow ? clampInt(pendingRow.count, 0, TRADE_MAX_QUEUE) : 0;
              return {
                job_id: row.job_id,
                provider_id: row.provider_id,
                input_resource_id: row.input_resource_id,
                input_amount: clampAmount(row.input_amount),
                output_resource_id: row.output_resource_id,
                output_min: clampAmount(row.output_min),
                output_max: clampAmount(row.output_max),
                duration_sec: clampInt(row.duration_sec, 0, TRADE_MAX_DURATION_SEC),
                commission_resource_id: row.commission_resource_id,
                commission_amount: clampAmount(row.commission_amount),
                queue_limit: clampInt(row.queue_limit, 1, TRADE_MAX_QUEUE),
                status: row.status,
                created_at: row.created_at,
                pending_count: pending
              };
            });
            return jsonResponse({ ok: true, jobs });
          }
          if (req.method == "POST" && url.pathname == "/trade/jobs") {
            const providerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:trade",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: providerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Trade: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const existing = getIdempotentState(providerId, clientActionId, "TRADE_JOB_CREATE", body);
              const jobId = makeTradeJobId(providerId, clientActionId);
              if (existing) {
                return stateResponseExtra(existing, { job_id: jobId });
              }
              const createResult = createTradeJob(providerId, clientActionId, body);
              if (createResult.error || !createResult.state || !createResult.jobId) {
                throw new HttpError(400, createResult.error || "Failed to create trade job.");
              }
              return stateResponseExtra(createResult.state, { job_id: createResult.jobId });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/trade/submit") {
            const customerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:trade",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: customerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Trade: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              getIdempotentState(customerId, clientActionId, "TRADE_SUBMIT", body);
              const submitResult = submitTradeRun(customerId, clientActionId, body);
              if (submitResult.error || !submitResult.state) {
                throw new HttpError(400, submitResult.error || "Failed to submit trade.");
              }
              return stateResponseExtra(submitResult.state, {
                run_id: submitResult.runId,
                completes_at: submitResult.completesAt
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/trade/claim") {
            const customerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:trade",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: customerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Trade: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              getIdempotentState(customerId, clientActionId, "TRADE_CLAIM", body);
              const claimResult = claimTradeRun(customerId, clientActionId, body);
              if (claimResult.error || !claimResult.state) {
                throw new HttpError(400, claimResult.error || "Failed to claim trade.");
              }
              return stateResponseExtra(claimResult.state, {
                output_amount: claimResult.outputAmount
              });
            }).immediate();
          }
          if (req.method == "GET" && url.pathname == "/world/state") {
            const playerId = await tryAuth(req, ctx);
            return db.transaction(() => {
              const now = Date.now();
              const worldState = ensureWorldState(now);
              if (playerId) {
                const state = ensurePlayerState(playerId);
                const world = ensurePlayerWorld(state, now);
                if (refreshWorldPlayer(world, now)) {
                  state.updated_at = now;
                  updatePlayerStmt.run(JSON.stringify(state), now, playerId);
                }
                return jsonResponse({
                  ok: true,
                  server_time_unix_ms: now,
                  world_state: worldState,
                  player_world: world
                });
              }
              return jsonResponse({
                ok: true,
                server_time_unix_ms: now,
                world_state: worldState
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/world/enter") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:world",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("World: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_ENTER", body);
              if (duplicate) {
                const zoneId = String(body.zone_id ?? "").trim();
                const sessionId = makeWorldSessionId(playerId, clientActionId, zoneId);
                return stateResponseExtra(duplicate, { session_id: sessionId, zone_id: zoneId, modifiers: duplicate.world.sessions[sessionId]?.modifiers ?? [], duplicate: true });
              }
              const debugBypass = isDebugBypass(req);
              const result = enterWorldSession(playerId, clientActionId, body, debugBypass);
              if (result.error || !result.state) {
                throw new HttpError(400, result.error || "Failed to enter world zone.");
              }
              return stateResponseExtra(result.state, {
                session_id: result.sessionId,
                zone_id: result.zoneId,
                modifiers: result.modifiers
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/world/farm") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:world",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("World: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_FARM", body);
              if (duplicate) {
                const sessionId = String(body.session_id ?? "");
                const zoneId = duplicate.world.sessions[sessionId]?.zone_id;
                return stateResponseExtra(duplicate, { session_id: sessionId, drops: {}, heat: zoneId ? duplicate.world.zone_progress[zoneId]?.heat ?? 0 : 0, stamina: duplicate.world.stamina, duplicate: true });
              }
              const result = farmWorldSession(playerId, clientActionId, body);
              if (result.error || !result.state) {
                throw new HttpError(400, result.error || "Failed to farm world zone.");
              }
              return stateResponseExtra(result.state, {
                session_id: result.sessionId,
                drops: result.drops,
                heat: result.heat,
                stamina: result.stamina
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/world/claim") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:world",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("World: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const duplicate = getIdempotentState(playerId, clientActionId, "WORLD_CLAIM", body);
              if (duplicate)
                return stateResponseExtra(duplicate, { session_id: body.session_id, claimed: {}, duplicate: true });
              const result = claimWorldSession(playerId, clientActionId, body);
              if (result.error || !result.state) {
                throw new HttpError(400, result.error || "Failed to claim world loot.");
              }
              return stateResponseExtra(result.state, {
                session_id: result.sessionId,
                claimed: result.claimed
              });
            }).immediate();
          }
          if (req.method == "GET" && url.pathname == "/world/boss-hunts") {
            return jsonResponse(soloBossSchedule(Date.now()));
          }
          if (req.method == "GET" && url.pathname == "/world/boss-hunts/session") {
            const playerId = await requireAuth(req, ctx);
            return db.transaction(() => {
              const now = Date.now();
              expireSoloHunts(playerId, now);
              const row = db.query("SELECT * FROM solo_hunt_sessions WHERE player_id = ? AND status = 'ACTIVE'").get(playerId);
              return jsonResponse({ session: row ? soloHuntResponse(row) : null, server_time_unix_ms: now });
            }).immediate();
          }
          if (req.method == "POST" && (url.pathname == "/world/boss-hunts/start" || url.pathname == "/world/boss-hunts/forfeit")) {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, { keyPrefix: "rl:action", windowSeconds: EXPENSIVE_RATE_WINDOW, max: EXPENSIVE_RATE_MAX, keyBy: "user", userId: playerId });
            const body = await readJson(req, config.maxBodyBytes);
            const actionId = typeof body?.client_action_id === "string" ? body.client_action_id.trim() : "";
            if (!actionId || actionId.length > 64)
              throw new HttpError(400, "Invalid client_action_id.");
            const start = url.pathname.endsWith("/start");
            const payload = start ? { hunt_id: body?.hunt_id, rotation_key: body?.rotation_key } : { session_id: body?.session_id };
            if (start ? typeof payload.hunt_id !== "string" || !Number.isSafeInteger(payload.rotation_key) : typeof payload.session_id !== "string" || !payload.session_id)
              throw new HttpError(400, "Invalid hunt request.");
            const actionType = start ? "SOLO_HUNT_START" : "SOLO_HUNT_FORFEIT";
            db.transaction(() => expireSoloHunts(playerId, Date.now())).immediate();
            return db.transaction(() => {
              const now = Date.now();
              expireSoloHunts(playerId, now);
              const prior = getActionStmt.get(playerId, actionId);
              if (prior) {
                let previous, result;
                try {
                  previous = JSON.parse(prior.payload_json);
                  result = JSON.parse(prior.result_state_json ?? "{}");
                } catch {
                  throw new HttpError(409, "Invalid stored action.");
                }
                if (prior.action_type !== actionType || canonicalActionPayload(previous) !== canonicalActionPayload(payload))
                  throw new HttpError(409, "Action ID already used with different content.");
                const existing = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ? AND player_id = ?").get(result.session_id, playerId);
                if (!existing)
                  throw new HttpError(409, "Session unavailable.");
                return jsonResponse({ ...soloHuntResponse(existing), duplicate: true });
              }
              let row;
              if (start) {
                const schedule = soloBossSchedule(now);
                const boss = schedule.bosses.find((candidate) => candidate.id === payload.hunt_id);
                if (payload.rotation_key !== schedule.rotation_key || !boss || !boss.available)
                  throw new HttpError(409, "Boss hunt is not available for this rotation.");
                if (db.query("SELECT 1 FROM solo_hunt_sessions WHERE player_id = ? AND status = 'ACTIVE'").get(playerId))
                  throw new HttpError(409, "An active boss hunt already exists.");
                const state = ensurePlayerState(playerId);
                const snapshot = { item_progress: state.item_progress ?? {}, homunculus_progress: state.homunculus_progress ?? {}, spell_progress: state.spell_progress ?? {}, research_flags: state.research_flags ?? {}, loadout_verification: "UNVERIFIED" };
                const sessionId = crypto.randomUUID();
                db.query("INSERT INTO solo_hunt_sessions (session_id,player_id,hunt_id,rotation_key,status,boss_snapshot_json,player_snapshot_json,started_at,expires_at) VALUES (?,?,?,?,'ACTIVE',?,?,?,?)").run(sessionId, playerId, boss.id, schedule.rotation_key, JSON.stringify(boss), JSON.stringify(snapshot), now, now + 2700000);
                row = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId);
              } else {
                const existing = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ? AND player_id = ?").get(payload.session_id, playerId);
                if (!existing)
                  throw new HttpError(404, "Session not found.");
                if (existing.status !== "ACTIVE" && existing.status !== "FORFEIT")
                  throw new HttpError(409, "Session is already closed.");
                if (existing.status === "ACTIVE")
                  db.query("UPDATE solo_hunt_sessions SET status = 'FORFEIT', finished_at = ? WHERE session_id = ? AND player_id = ? AND status = 'ACTIVE'").run(now, existing.session_id, playerId);
                row = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ?").get(existing.session_id);
              }
              insertActionStmt.run(playerId, actionId, actionType, JSON.stringify(payload), JSON.stringify({ session_id: row.session_id }), now);
              return jsonResponse(soloHuntResponse(row));
            }).immediate();
          }
          if (req.method == "GET" && url.pathname == "/boss/state") {
            return db.transaction(() => {
              const now = Date.now();
              const worldState = ensureWorldState(now);
              return jsonResponse({
                ok: true,
                server_time_unix_ms: now,
                bosses: worldState.bosses
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/boss/attack") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:boss",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Boss: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const duplicate = getIdempotentState(playerId, clientActionId, "BOSS_ATTACK", body);
              if (duplicate) {
                const boss = getBossFromWorld(ensureWorldState(Date.now()), String(body.boss_id ?? ""));
                return stateResponseExtra(duplicate, boss ? { duplicate: true, damage: 0, boss_hp: boss.hp, boss_max_hp: boss.max_hp, phase: boss.phase, contributor_score: boss.contributors[playerId] ?? 0, tokens_earned: 0 } : { duplicate: true });
              }
              const ip = getClientIp(req);
              const result = attackBoss(playerId, clientActionId, body, ip);
              if (result.error || !result.state || !result.boss) {
                throw new HttpError(400, result.error || "Failed to attack boss.");
              }
              return stateResponseExtra(result.state, {
                damage: result.damage ?? 0,
                boss_hp: result.boss.hp,
                boss_max_hp: result.boss.max_hp,
                phase: result.boss.phase,
                contributor_score: result.contributorScore ?? 0,
                tokens_earned: result.tokens ?? 0
              });
            }).immediate();
          }
          if (req.method == "POST" && url.pathname == "/boss/claim_rewards") {
            const playerId = await requireAuth(req, ctx);
            await applyRateLimit(ctx, {
              keyPrefix: "rl:boss",
              windowSeconds: EXPENSIVE_RATE_WINDOW,
              max: EXPENSIVE_RATE_MAX,
              keyBy: "user",
              userId: playerId
            });
            const body = await readJson(req, config.maxBodyBytes);
            const clientActionId = typeof body?.client_action_id == "string" ? body.client_action_id.trim() : "";
            if (!clientActionId || clientActionId.length > 64) {
              console.warn("Boss: missing client_action_id", body);
              throw new HttpError(400, "Missing client_action_id.");
            }
            return db.transaction(() => {
              const duplicate = getIdempotentState(playerId, clientActionId, "BOSS_CLAIM", body);
              if (duplicate)
                return stateResponseExtra(duplicate, { claimed: {}, duplicate: true });
              const result = claimBossRewards(playerId, clientActionId, body);
              if (result.error || !result.state) {
                throw new HttpError(400, result.error || "Failed to claim boss rewards.");
              }
              return stateResponseExtra(result.state, {
                tier: result.tier ?? "none",
                claimed: result.claimed ?? {}
              });
            }).immediate();
          }
          if (req.method == "GET" && url.pathname == "/static/version") {
            return await staticVersionResponse();
          }
          if (req.method == "GET" && url.pathname == "/health") {
            return await healthResponse();
          }
          if (req.method == "GET" && url.pathname == "/metrics") {
            return await metricsResponse();
          }
          return jsonResponse({ error: "Not found" }, 404);
        })();
        const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
        recordRequest(finalRes.status, Date.now() - ctx.startAt);
        logInfo("request", {
          req_id: ctx.requestId,
          method: req.method,
          path: ctx.path,
          status: finalRes.status,
          latency_ms: Date.now() - ctx.startAt
        });
        return finalRes;
      } catch (err) {
        recordError();
        const sqliteBusy = typeof err === "object" && err !== null && typeof err.code === "string" && String(err.code).startsWith("SQLITE_BUSY");
        const message = sqliteBusy ? "Database temporarily busy; retry the same action ID." : err instanceof HttpError || err instanceof CombatRewardError || err instanceof AccountStatusUnavailableError ? err.message : "Internal server error";
        const status = sqliteBusy || err instanceof AccountStatusUnavailableError ? 503 : err instanceof HttpError || err instanceof CombatRewardError ? err.status : 500;
        const res = errorResponse(message, status);
        const finalRes = applyResponseHeaders(res, ctx, corsHeaders);
        recordRequest(finalRes.status, Date.now() - ctx.startAt);
        logError("request error", {
          req_id: ctx.requestId,
          method: req.method,
          path: ctx.path,
          status,
          error: String(err)
        });
        return finalRes;
      }
    },
    websocket: {
      open(ws) {
        sockets.add(ws);
        ws.send(JSON.stringify({ type: "hello", server_time: Date.now() }));
      },
      message(ws, message) {
        if (typeof message == "string" && message.toLowerCase() == "ping") {
          ws.send("pong");
        }
      },
      close(ws) {
        sockets.delete(ws);
      }
    }
  });
  console.log(`Backend listening on http://${config.host}:${config.port}`);
}
function loadStaticData() {
  const staticDir = resolve2(import.meta.dir, "..", "..", "data", "static");
  const itemsRaw = JSON.parse(readFileSync2(resolve2(staticDir, "..", "items.json"), "utf8"));
  const homunculiRaw = JSON.parse(readFileSync2(resolve2(staticDir, "..", "homunculi.json"), "utf8"));
  const mutationsRaw = JSON.parse(readFileSync2(resolve2(staticDir, "mutations.json"), "utf8"));
  const itemIds = new Set((Array.isArray(itemsRaw.items) ? itemsRaw.items : []).map((item) => item.id).filter((id) => typeof id === "string"));
  const itemRarities = Object.fromEntries((Array.isArray(itemsRaw.items) ? itemsRaw.items : []).filter((item) => typeof item.id === "string" && typeof item.rarity === "string").map((item) => [item.id, item.rarity]));
  const resources = loadResourceIds(resolve2(staticDir, "resources.json"));
  const buildingsData = loadBuildings(resolve2(staticDir, "buildings.json"));
  const balance = loadBalance(resolve2(staticDir, "balance.json"));
  const researchData = loadResearch(resolve2(staticDir, "research.json"));
  const zones = loadZones(resolve2(staticDir, "zones.json"));
  const bosses = loadBosses(resolve2(staticDir, "bosses.json"));
  return {
    itemIds,
    homunculusIds: new Set((homunculiRaw.homunculi ?? []).map((entry) => entry.id).filter((id) => typeof id === "string")),
    mutationIds: new Set((mutationsRaw.mutations ?? []).map((entry) => entry.id).filter((id) => typeof id === "string")),
    itemRarities,
    resources: resources.ids,
    buildings: buildingsData.buildings,
    hqPaths: buildingsData.hqPaths,
    balance,
    research: researchData.nodes,
    researchFlags: researchData.flags,
    zones,
    bosses,
    soloBosses: loadSoloBossCatalog(resolve2(staticDir, "solo_bosses.json"), resolve2(staticDir, "..", "spells.json"))
  };
}
function loadSoloBossCatalog(path, spellsPath) {
  const catalog = readJsonFile(path), spells2 = readJsonFile(spellsPath);
  const tiers = ["common", "mythic", "rare", "epic", "legendary"];
  const rotation = catalog?.rotation;
  const invalid = () => {
    throw new Error("Invalid solo boss catalog configuration.");
  };
  if (!rotation || !Number.isSafeInteger(rotation.interval_seconds) || rotation.interval_seconds !== 900 || !Number.isSafeInteger(rotation.window_seconds) || rotation.window_seconds !== 720 || !Number.isSafeInteger(rotation.common_cooldown_seconds) || rotation.common_cooldown_seconds !== 60 || !rotation.weights || Object.keys(rotation.weights).sort().join(",") !== tiers.slice(1).sort().join(",") || tiers.slice(1).some((tier) => typeof rotation.weights[tier] !== "number" || !Number.isFinite(rotation.weights[tier]) || rotation.weights[tier] <= 0) || Math.abs(tiers.slice(1).reduce((sum, tier) => sum + rotation.weights[tier], 0) - 1) > 0.000001 || !Array.isArray(catalog?.bosses) || catalog.bosses.length !== 5 || !Array.isArray(spells2?.spells))
    return invalid();
  const spellIds = new Set(spells2.spells.map((spell) => spell.id));
  const bossTextures = ["boss_common", "boss_colossus", "boss_leviathan", "tier3boss", "scorpion_boss", "boss_temporal", "ghost_boss"];
  const seenIds = new Set, seenTiers = new Set;
  for (const boss of catalog.bosses) {
    if (!boss || typeof boss.id !== "string" || !/^hunt_[a-z0-9_]+$/.test(boss.id) || seenIds.has(boss.id) || !tiers.includes(boss.tier) || seenTiers.has(boss.tier) || typeof boss.name !== "string" || !boss.name.trim() || !bossTextures.includes(boss.texture_id) || boss.texture_variants !== undefined && (!Array.isArray(boss.texture_variants) || boss.texture_variants.length === 0 || new Set(boss.texture_variants).size !== boss.texture_variants.length || !boss.texture_variants.includes(boss.texture_id) || boss.texture_variants.some((id) => typeof id !== "string" || !bossTextures.includes(id))) || (boss.minions > 0 ? boss.minion_texture_id !== "summoned-boss" : boss.minion_texture_id !== undefined && boss.minion_texture_id !== "summoned-boss") || [boss.hp_mult, boss.attack_mult, boss.fury_mult].some((value) => typeof value !== "number" || !Number.isFinite(value) || value <= 0) || [boss.shield_reduction, boss.shield_heal_ratio].some((value) => typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) || !Number.isSafeInteger(boss.minions) || boss.minions < 0 || boss.minions > 2 || !Number.isSafeInteger(boss.shield_turns) || boss.shield_turns < 1 || !Array.isArray(boss.signature_pool) || boss.signature_pool.length === 0 || boss.signature_pool.some((id) => typeof id !== "string" || !spellIds.has(id)))
      return invalid();
    seenIds.add(boss.id);
    seenTiers.add(boss.tier);
  }
  return catalog;
}
function expireSoloHunts(playerId, now) {
  db.query("UPDATE solo_hunt_sessions SET status = 'EXPIRED', finished_at = ? WHERE player_id = ? AND status = 'ACTIVE' AND expires_at <= ?").run(now, playerId, now);
}
function soloHuntResponse(row) {
  return { session_id: row.session_id, hunt_id: row.hunt_id, rotation_key: row.rotation_key, status: row.status, started_at: row.started_at, expires_at: row.expires_at, finished_at: row.finished_at, boss_definition: JSON.parse(row.boss_snapshot_json) };
}
function soloBossSchedule(now) {
  const { rotation, bosses } = staticData.soloBosses;
  const interval = rotation.interval_seconds * 1000, window2 = rotation.window_seconds * 1000;
  const key = Math.floor(now / interval), start = key * interval, end = start + window2;
  const roll = createHmac("sha256", WORLD_SECRET).update(String(key)).digest().readUInt32BE(0) / 4294967296;
  let cumulative = 0, chosen = "legendary";
  for (const tier of ["mythic", "rare", "epic", "legendary"]) {
    cumulative += rotation.weights[tier];
    if (roll < cumulative) {
      chosen = tier;
      break;
    }
  }
  const special = bosses.find((boss) => boss.tier === chosen);
  return { server_time_unix_ms: now, rotation_key: key, current_special_id: special.id, next_rotation_at: start + interval, special_window_ends_at: end, bosses: bosses.map((boss) => ({ ...boss, display_texture_id: boss.texture_variants?.[key % boss.texture_variants.length] ?? boss.texture_id, available: boss.tier === "common" || boss.id === special.id && now < end, appearance_starts_at: boss.tier === "common" ? null : boss.id === special.id ? start : null, appearance_ends_at: boss.tier === "common" ? null : boss.id === special.id ? end : null })) };
}
function loadResourceIds(path) {
  const fallback = [
    "essence",
    "core",
    "arcane_shard",
    "time_crystal"
  ];
  const data = readJsonFile(path);
  if (!data || typeof data != "object") {
    return { ids: new Set(fallback) };
  }
  const list = data.resources;
  if (!Array.isArray(list)) {
    return { ids: new Set(fallback) };
  }
  const ids = new Set;
  for (const entry of list) {
    if (entry && typeof entry.id == "string") {
      ids.add(entry.id);
    }
  }
  return { ids: ids.size > 0 ? ids : new Set(fallback) };
}
function loadBuildings(path) {
  const fallbackIds = [
    "lab_th",
    "essence_reactor",
    "storage_vault",
    "build_forge",
    "homunculus_vat",
    "ultrahit_tower",
    "experiment_chamber",
    "arcane_archives",
    "sync_nexus",
    "anomaly_containment",
    "trade_hall",
    "world_gate"
  ];
  const data = readJsonFile(path);
  if (!data || typeof data != "object") {
    const fallback = {};
    for (const id of fallbackIds) {
      fallback[id] = { id };
    }
    return { buildings: fallback, hqPaths: ["Scientific", "Chaotic", "Industrial"] };
  }
  const list = data.buildings;
  const hqPaths = Array.isArray(data.hq_paths) ? data.hq_paths : ["Scientific", "Chaotic", "Industrial"];
  const out = {};
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (entry && typeof entry.id == "string") {
        out[entry.id] = entry;
      }
    }
  }
  if (Object.keys(out).length == 0) {
    for (const id of fallbackIds) {
      out[id] = { id };
    }
  }
  return { buildings: out, hqPaths };
}
function loadZones(path) {
  const fallback = defaultZoneDefs();
  const fallbackMap = new Map;
  for (const entry of fallback) {
    fallbackMap.set(entry.id, entry);
  }
  const data = readJsonFile(path);
  const list = data && typeof data == "object" ? data.zones : null;
  const out = {};
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (!entry || typeof entry.id != "string") {
        continue;
      }
      const id = entry.id.trim();
      if (!id || out[id]) {
        continue;
      }
      const name = typeof entry.name == "string" ? entry.name.trim() : id;
      let drops = normalizeDropTable(entry.drops);
      let rareDrops = normalizeDropTable(entry.rare_drops);
      const fallbackZone = fallbackMap.get(id);
      if (Object.keys(drops).length == 0) {
        drops = fallbackZone?.drops ?? { essence: 1 };
      }
      if (Object.keys(rareDrops).length == 0 && fallbackZone?.rare_drops) {
        rareDrops = fallbackZone.rare_drops;
      }
      const modifiers = Array.isArray(entry.modifiers) ? entry.modifiers.map((value) => typeof value == "string" ? value.trim() : "").filter((value) => value.length > 0) : fallbackZone?.modifiers ?? [];
      const zone = {
        id,
        name,
        drops
      };
      if (Object.keys(rareDrops).length > 0) {
        zone.rare_drops = rareDrops;
      }
      if (modifiers.length > 0) {
        zone.modifiers = modifiers;
      }
      out[id] = zone;
    }
  }
  if (Object.keys(out).length == 0) {
    for (const entry of fallback) {
      out[entry.id] = entry;
    }
  }
  return out;
}
function loadBosses(path) {
  const fallback = defaultBossDefs();
  const fallbackMap = new Map;
  for (const entry of fallback) {
    fallbackMap.set(entry.id, entry);
  }
  const data = readJsonFile(path);
  const list = data && typeof data == "object" ? data.bosses : null;
  const out = {};
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (!entry || typeof entry.id != "string") {
        continue;
      }
      const id = entry.id.trim();
      if (!id || out[id]) {
        continue;
      }
      const name = typeof entry.name == "string" ? entry.name.trim() : id;
      const modifiers = normalizeModifierList(entry.modifiers);
      const maxHp = clampInt(entry.max_hp ?? 0, 0, Number.MAX_SAFE_INTEGER);
      const fallbackBoss = fallbackMap.get(id);
      out[id] = {
        id,
        name,
        modifiers: modifiers.length > 0 ? modifiers : fallbackBoss?.modifiers,
        max_hp: maxHp > 0 ? maxHp : fallbackBoss?.max_hp
      };
    }
  }
  if (Object.keys(out).length == 0) {
    for (const entry of fallback) {
      out[entry.id] = entry;
    }
  }
  return out;
}
function loadBalance(path) {
  const data = readJsonFile(path);
  if (!data || typeof data != "object") {
    return {};
  }
  if (data.balance && typeof data.balance == "object") {
    return data.balance;
  }
  return data;
}
function loadResearch(path) {
  const fallback = defaultResearchNodes();
  const data = readJsonFile(path);
  const list = data && typeof data == "object" ? data.research : null;
  const nodes = {};
  if (Array.isArray(list)) {
    for (const entry of list) {
      if (!entry || typeof entry.id != "string") {
        continue;
      }
      const id = entry.id.trim();
      if (!id || nodes[id]) {
        continue;
      }
      const name = typeof entry.name == "string" ? entry.name.trim() : id;
      const flagId = typeof entry.flag_id == "string" ? entry.flag_id.trim() : "";
      const cost = entry.cost && typeof entry.cost == "object" ? entry.cost : {};
      const timeSec = typeof entry.time_sec == "number" ? entry.time_sec : Number(entry.time_sec);
      const requires = Array.isArray(entry.requires) ? entry.requires.filter((v) => typeof v == "string") : [];
      if (!flagId || !Number.isFinite(timeSec)) {
        continue;
      }
      nodes[id] = {
        id,
        name,
        flag_id: flagId,
        cost,
        time_sec: Math.max(0, Math.floor(timeSec)),
        requires
      };
    }
  }
  if (Object.keys(nodes).length == 0) {
    for (const entry of fallback) {
      nodes[entry.id] = entry;
    }
  }
  const flags = new Set;
  for (const node of Object.values(nodes)) {
    if (node.flag_id) {
      flags.add(node.flag_id);
    }
  }
  return { nodes, flags };
}
function normalizeDropTable(raw) {
  const out = {};
  if (!raw || typeof raw != "object") {
    return out;
  }
  for (const [key, value] of Object.entries(raw)) {
    const id = typeof key == "string" ? key.trim() : "";
    if (!id) {
      continue;
    }
    const weight = typeof value == "number" ? value : Number(value);
    if (!Number.isFinite(weight) || weight <= 0) {
      continue;
    }
    out[id] = weight;
  }
  return out;
}
function defaultZoneDefs() {
  return [
    {
      id: "zone_corrupted",
      name: "Corrupted Zone",
      drops: {
        essence: 70,
        arcane_shard: 30
      },
      rare_drops: {
        time_crystal: 10
      },
      modifiers: ["corrupt_fog", "unstable_flux", "spiteful_echoes"]
    },
    {
      id: "zone_crystal",
      name: "Crystal Zone",
      drops: {
        essence: 60,
        core: 25,
        time_crystal: 15
      },
      rare_drops: {
        time_crystal: 4,
        arcane_shard: 6
      },
      modifiers: ["resonant_growth", "shard_bloom", "prismatic_shift"]
    },
    {
      id: "zone_chaos",
      name: "Chaos Zone",
      drops: {
        essence: 50,
        arcane_shard: 40,
        core: 10
      },
      rare_drops: {
        time_crystal: 10
      },
      modifiers: ["entropy_surge", "wild_flux", "rift_winds"]
    }
  ];
}
function defaultBossDefs() {
  return [
    {
      id: "boss_common",
      name: "Common Boss",
      modifiers: ["staggering_roar", "volatile_hide"],
      max_hp: 50000
    },
    {
      id: "boss_colossus",
      name: "Giant Arcane Colossus",
      modifiers: ["arcane_bulwark", "runic_spikes"],
      max_hp: 120000
    },
    {
      id: "boss_leviathan",
      name: "Corrupted Energy Leviathan",
      modifiers: ["corrupt_surge", "void_tide"],
      max_hp: 90000
    },
    {
      id: "boss_temporal",
      name: "Temporal Warden Titan",
      modifiers: ["time_dilation", "chronoshield"],
      max_hp: 150000
    }
  ];
}
function defaultResearchNodes() {
  return [
    {
      id: "archive_basics",
      name: "Archive Basics",
      flag_id: "archive_basics",
      cost: { essence: 30 },
      time_sec: 30,
      requires: []
    },
    {
      id: "trade_jobs",
      name: "Trade Jobs",
      flag_id: "unlock_trade_jobs",
      cost: { essence: 80, core: 5 },
      time_sec: 120,
      requires: ["archive_basics"]
    },
    {
      id: "world_zones",
      name: "World Zones",
      flag_id: "unlock_world_zones",
      cost: { essence: 120, arcane_shard: 2 },
      time_sec: 180,
      requires: ["archive_basics"]
    },
    {
      id: "sync_theory",
      name: "Sync Theory",
      flag_id: "unlock_sync",
      cost: { essence: 150, core: 10 },
      time_sec: 240,
      requires: ["unlock_world_zones"]
    },
    {
      id: "anomaly_theory",
      name: "Anomaly Theory",
      flag_id: "unlock_anomalies",
      cost: { essence: 200, arcane_shard: 2 },
      time_sec: 300,
      requires: ["unlock_sync"]
    },
    {
      id: "experiment_cooldown",
      name: "Experiment Cooldown",
      flag_id: "reduce_experiment_cooldown",
      cost: { essence: 100, arcane_shard: 2 },
      time_sec: 180,
      requires: ["archive_basics"]
    },
    {
      id: "storage_protocols",
      name: "Storage Protocols",
      flag_id: "increase_storage_capacity",
      cost: { essence: 110, core: 4 },
      time_sec: 180,
      requires: ["archive_basics"]
    },
    {
      id: "reactor_notes",
      name: "Reactor Notes",
      flag_id: "reactor_efficiency",
      cost: { essence: 90, core: 3 },
      time_sec: 150,
      requires: ["archive_basics"]
    },
    {
      id: "arcane_catalog",
      name: "Arcane Catalog",
      flag_id: "unlock_arcane_catalog",
      cost: { essence: 130, arcane_shard: 3 },
      time_sec: 200,
      requires: ["reactor_efficiency"]
    },
    {
      id: "gateway_studies",
      name: "Gateway Studies",
      flag_id: "unlock_gateway_studies",
      cost: { essence: 160, time_crystal: 1 },
      time_sec: 220,
      requires: ["unlock_world_zones"]
    }
  ];
}
function readJsonFile(path) {
  try {
    if (!existsSync(path)) {
      console.error(`Static data missing: ${path}`);
      return null;
    }
    const raw = readFileSync2(path, "utf8");
    return JSON.parse(raw);
  } catch (err) {
    console.error(`Failed to read JSON: ${path}`, err);
    return null;
  }
}
function normalizeWallet(walletRaw) {
  const wallet = {};
  const allowAll = staticData.resources.size == 0;
  if (walletRaw && typeof walletRaw == "object") {
    for (const [key, value] of Object.entries(walletRaw)) {
      if (!allowAll && !staticData.resources.has(key)) {
        continue;
      }
      const amount = clampAmount(value);
      if (amount >= 0) {
        wallet[key] = amount;
      }
    }
  } else if (typeof walletRaw == "number") {
    const amount = clampAmount(walletRaw);
    if (amount > 0) {
      wallet["essence"] = amount;
    }
  }
  if (!allowAll) {
    for (const id of staticData.resources) {
      if (wallet[id] == null) {
        wallet[id] = 0;
      }
    }
  }
  return wallet;
}
function normalizeLoot(raw) {
  const out = {};
  if (!raw || typeof raw != "object") {
    return out;
  }
  const allowAll = staticData.resources.size == 0;
  for (const [key, value] of Object.entries(raw)) {
    if (!allowAll && !staticData.resources.has(key)) {
      continue;
    }
    const amount = clampAmount(value);
    if (amount > 0) {
      out[key] = amount;
    }
  }
  return out;
}
function normalizeResearchFlags(raw) {
  const out = {};
  const allowAll = staticData.researchFlags.size == 0;
  if (raw && typeof raw == "object") {
    for (const [key, value] of Object.entries(raw)) {
      if (!allowAll && !staticData.researchFlags.has(key)) {
        continue;
      }
      if (value) {
        out[key] = true;
      }
    }
  }
  return out;
}
function normalizeLab(labRaw) {
  const hqPaths = staticData.hqPaths.length > 0 ? staticData.hqPaths : ["Scientific"];
  const defaultPath = hqPaths[0];
  const hqLevel = clampInt(labRaw?.hqLevel ?? 1, 0, 999);
  const hqPath = canonicalHqPath(labRaw?.hqPath, hqPaths) ?? defaultPath;
  const runtime = normalizeLabRuntime(labRaw?.runtime);
  const buildings = {};
  const rawBuildings = labRaw?.buildings;
  if (rawBuildings && typeof rawBuildings == "object") {
    for (const [id, entry] of Object.entries(rawBuildings)) {
      if (!staticData.buildings[id]) {
        continue;
      }
      const data = entry;
      const level = clampInt(data?.level ?? 0, 0, 999);
      const route = typeof data?.route == "string" ? data.route : "";
      const runtime2 = data?.runtime && typeof data.runtime == "object" ? data.runtime : {};
      buildings[id] = {
        level,
        route,
        runtime: {
          stored_output: clampAmount(runtime2.stored_output ?? 0),
          last_tick: clampInt(runtime2.last_tick ?? Date.now(), 0, Number.MAX_SAFE_INTEGER)
        }
      };
    }
  }
  if (!buildings["lab_th"]) {
    buildings["lab_th"] = { level: hqLevel, route: hqPath, runtime: {} };
  } else if (buildings["lab_th"].level < hqLevel) {
    buildings["lab_th"].level = hqLevel;
  }
  return {
    hqLevel,
    hqPath,
    buildings,
    runtime
  };
}
function normalizeLabRuntime(runtimeRaw) {
  const cooldowns = {};
  const boosts = {};
  const research = {};
  if (runtimeRaw && typeof runtimeRaw == "object") {
    const rawCooldowns = runtimeRaw.cooldowns;
    if (rawCooldowns && typeof rawCooldowns == "object") {
      for (const [id, value] of Object.entries(rawCooldowns)) {
        const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
        if (ts > 0) {
          cooldowns[id] = ts;
        }
      }
    }
    const rawBoosts = runtimeRaw.boosts;
    if (rawBoosts && typeof rawBoosts == "object") {
      for (const [id, value] of Object.entries(rawBoosts)) {
        if (typeof value == "number") {
          const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
          if (ts > 0) {
            boosts[id] = { started_at: 0, expires_at: ts };
          }
          continue;
        }
        if (value && typeof value == "object") {
          const ts = clampInt(value.expires_at, 0, Number.MAX_SAFE_INTEGER);
          if (ts > 0) {
            boosts[id] = { started_at: clampInt(value.started_at ?? 0, 0, ts), expires_at: ts };
          }
        }
      }
    }
    const rawResearch = runtimeRaw.research;
    if (rawResearch && typeof rawResearch == "object") {
      const activeId = typeof rawResearch.active_id == "string" ? rawResearch.active_id : "";
      const startedAt = clampInt(rawResearch.started_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
      const completesAt = clampInt(rawResearch.completes_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
      if (activeId && completesAt > 0) {
        research.active_id = activeId;
        research.started_at = startedAt;
        research.completes_at = completesAt;
        if (typeof rawResearch.queued_id === "string" && rawResearch.queued_id !== activeId && staticData.research[rawResearch.queued_id])
          research.queued_id = rawResearch.queued_id;
      }
    }
  }
  const result = { cooldowns, boosts, research };
  result.experiment_stability = { failures: clampInt(runtimeRaw?.experiment_stability?.failures, 0, 3) };
  const last = runtimeRaw?.experiment_last;
  if (last && typeof last.id === "string" && typeof last.success === "boolean" && Number.isFinite(last.chance))
    result.experiment_last = { id: last.id, success: last.success, chance: clampChance(last.chance), at: clampInt(last.at, 0, Number.MAX_SAFE_INTEGER), expires_at: clampInt(last.expires_at, 0, Number.MAX_SAFE_INTEGER) };
  const directive = runtimeRaw?.directive;
  if (directive && ["production", "research", "experimentation"].includes(directive.id)) {
    const starts = clampInt(directive.starts_at, 0, Number.MAX_SAFE_INTEGER);
    const ends = clampInt(directive.ends_at, 0, Number.MAX_SAFE_INTEGER);
    if (ends > starts)
      result.directive = { id: directive.id, starts_at: starts, ends_at: ends };
  }
  if (runtimeRaw?.reactor_overcharge && typeof runtimeRaw.reactor_overcharge === "object")
    result.reactor_overcharge = { progress: clampInt(runtimeRaw.reactor_overcharge.progress, 0, Math.max(1, getBalanceNumber("reactor_overcharge_threshold", 300))), last_used_at: clampInt(runtimeRaw.reactor_overcharge.last_used_at, 0, Number.MAX_SAFE_INTEGER) };
  const anomaly = runtimeRaw?.anomaly;
  if (anomaly && typeof anomaly === "object" && ["seal", "investigate"].includes(anomaly.last_choice)) {
    const reward = {};
    if (anomaly.last_reward && typeof anomaly.last_reward === "object" && !Array.isArray(anomaly.last_reward)) {
      for (const [id, amount] of Object.entries(anomaly.last_reward))
        if (["essence", "core", "arcane_shard", "time_crystal"].includes(id) && Number.isSafeInteger(amount) && amount >= 0)
          reward[id] = amount;
    }
    result.anomaly = { next_at: clampInt(anomaly.next_at, 0, Number.MAX_SAFE_INTEGER), last_at: clampInt(anomaly.last_at, 0, Number.MAX_SAFE_INTEGER), last_choice: anomaly.last_choice, last_reward: reward };
  }
  const sync = runtimeRaw?.sync_project;
  if (sync && sync.project_id === "calibration" && sync.partner_kind === "npc" && sync.partner_id === "echo") {
    const started = clampInt(sync.started_at, 0, Number.MAX_SAFE_INTEGER);
    const completes = clampInt(sync.completes_at, 0, Number.MAX_SAFE_INTEGER);
    if (started > 0 && completes > started)
      result.sync_project = { project_id: "calibration", partner_kind: "npc", partner_id: "echo", started_at: started, completes_at: completes };
  }
  const trade = runtimeRaw?.npc_trade;
  if (trade && typeof trade === "object") {
    const normalizeUses = (raw, prefix, max) => {
      const uses = {};
      if (raw && typeof raw === "object" && !Array.isArray(raw)) {
        for (const [id, amount] of Object.entries(raw))
          if (new RegExp(`^${prefix}[1-${max}]$`).test(id) && Number.isSafeInteger(amount) && amount >= 0)
            uses[id] = amount;
      }
      return uses;
    };
    result.npc_trade = { day_key: clampInt(trade.day_key, 0, Number.MAX_SAFE_INTEGER), week_key: clampInt(trade.week_key, 0, Number.MAX_SAFE_INTEGER), daily_uses: normalizeUses(trade.daily_uses, "d", 8), weekly_uses: normalizeUses(trade.weekly_uses, "w", 6) };
  }
  return result;
}
function npcTradeOffers(runtime, now) {
  const values2 = staticData.balance.npc_trade_values;
  const daily = staticData.balance.npc_trade_daily;
  const weekly = staticData.balance.npc_trade_weekly;
  const ids = ["essence", "core", "arcane_shard", "time_crystal"];
  if (!values2 || typeof values2 !== "object" || Object.keys(values2).sort().join(",") !== [...ids].sort().join(",") || ids.some((id) => !Number.isSafeInteger(values2[id]) || values2[id] <= 0) || !Array.isArray(daily) || daily.length !== 8 || !Array.isArray(weekly) || weekly.length !== 6)
    throw new HttpError(503, "Invalid NPC trade configuration.");
  const seen = new Set;
  const amountValue = (amounts) => {
    if (!amounts || typeof amounts !== "object" || Array.isArray(amounts) || Object.keys(amounts).length !== 1)
      throw new HttpError(503, "Invalid NPC trade configuration.");
    const [id, amount] = Object.entries(amounts)[0];
    if (!ids.includes(id) || !staticData.resources.has(id) || !Number.isSafeInteger(amount) || amount <= 0 || !Number.isSafeInteger(amount * values2[id]))
      throw new HttpError(503, "Invalid NPC trade configuration.");
    return amount * values2[id];
  };
  for (const [pool, prefix] of [[daily, "d"], [weekly, "w"]])
    for (let i = 0;i < pool.length; i++) {
      const offer = pool[i];
      if (!offer || offer.id !== `${prefix}${i + 1}` || seen.has(offer.id))
        throw new HttpError(503, "Invalid NPC trade configuration.");
      seen.add(offer.id);
      const payValue = amountValue(offer.pay), receiveValue = amountValue(offer.receive);
      if (Object.keys(offer.pay)[0] === Object.keys(offer.receive)[0] || !Number.isSafeInteger(payValue * 4) || !Number.isSafeInteger(receiveValue * 5) || payValue * 4 < receiveValue * 5)
        throw new HttpError(503, "Invalid NPC trade configuration.");
    }
  const day = Math.floor(now / 86400000), week = Math.floor((day + 3) / 7);
  const counts = runtime.npc_trade;
  const select2 = (pool, period, key, quantity, step, max) => Array.from({ length: quantity }, (_, i) => {
    const offer = pool[(key + step * i) % pool.length];
    const uses = period === "daily" ? counts?.day_key === day ? counts.daily_uses : {} : counts?.week_key === week ? counts.weekly_uses : {};
    return { id: offer.id, period, period_key: key, pay: offer.pay, receive: offer.receive, max, remaining: Math.max(0, max - (uses[offer.id] ?? 0)) };
  });
  return { offers: [...select2(daily, "daily", day, 3, 3, 2), ...select2(weekly, "weekly", week, 2, 2, 1)], day_key: day, week_key: week, next_daily_at: (day + 1) * 86400000, next_weekly_at: ((week + 1) * 7 - 3) * 86400000 };
}
function normalizeWorld(worldRaw, now) {
  const zoneProgress = {};
  const rawProgress = worldRaw?.zone_progress;
  if (rawProgress && typeof rawProgress == "object") {
    for (const [zoneId, value] of Object.entries(rawProgress)) {
      if (!isValidZoneId(zoneId)) {
        continue;
      }
      const entry = value;
      const heat = clampInt(entry?.heat ?? 0, 0, Number.MAX_SAFE_INTEGER);
      const reputation = clampInt(entry?.reputation ?? 0, 0, Number.MAX_SAFE_INTEGER);
      const lastHeatAt = clampInt(entry?.last_heat_at ?? now, 0, Number.MAX_SAFE_INTEGER);
      zoneProgress[zoneId] = { heat, reputation, last_heat_at: lastHeatAt };
    }
  }
  const sessions = {};
  const rawSessions = worldRaw?.sessions;
  if (rawSessions && typeof rawSessions == "object") {
    for (const [sessionId, value] of Object.entries(rawSessions)) {
      if (!sessionId) {
        continue;
      }
      const entry = value;
      const zoneId = typeof entry?.zone_id == "string" ? entry.zone_id.trim() : "";
      if (!zoneId || !isValidZoneId(zoneId)) {
        continue;
      }
      const modifiers = normalizeModifierList(entry?.modifiers);
      sessions[sessionId] = {
        session_id: sessionId,
        zone_id: zoneId,
        started_at: clampInt(entry?.started_at ?? now, 0, Number.MAX_SAFE_INTEGER),
        last_farm_at: clampInt(entry?.last_farm_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
        pending_loot: normalizeLoot(entry?.pending_loot),
        blocks_farmed: clampInt(entry?.blocks_farmed ?? 0, 0, Number.MAX_SAFE_INTEGER),
        modifiers
      };
    }
  }
  const maxStamina = getWorldMaxStamina();
  const stamina = clampInt(worldRaw?.stamina ?? maxStamina, 0, maxStamina);
  const lastStaminaAt = clampInt(worldRaw?.last_stamina_at ?? now, 0, Number.MAX_SAFE_INTEGER);
  const dailyEntries = clampInt(worldRaw?.daily_entries ?? 0, 0, Number.MAX_SAFE_INTEGER);
  const lastEntryResetAt = clampInt(worldRaw?.last_entry_reset_at ?? now, 0, Number.MAX_SAFE_INTEGER);
  const maxTickets = getBossTicketMax();
  const bossTickets = clampInt(worldRaw?.boss_tickets ?? maxTickets, 0, maxTickets);
  const lastBossTicketAt = clampInt(worldRaw?.last_boss_ticket_at ?? now, 0, Number.MAX_SAFE_INTEGER);
  const bossTokens = clampInt(worldRaw?.boss_tokens ?? 0, 0, Number.MAX_SAFE_INTEGER);
  const bossClaims = {};
  const rawClaims = worldRaw?.boss_claims;
  if (rawClaims && typeof rawClaims == "object") {
    for (const [bossId, value] of Object.entries(rawClaims)) {
      if (!isValidBossId(bossId)) {
        continue;
      }
      const ts = clampInt(value, 0, Number.MAX_SAFE_INTEGER);
      if (ts > 0) {
        bossClaims[bossId] = ts;
      }
    }
  }
  const world = {
    zone_progress: zoneProgress,
    daily_entries: dailyEntries,
    last_entry_reset_at: lastEntryResetAt,
    last_gate_entry_at: clampInt(worldRaw?.last_gate_entry_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
    stamina,
    last_stamina_at: lastStaminaAt,
    boss_tickets: bossTickets,
    last_boss_ticket_at: lastBossTicketAt,
    boss_claims: bossClaims,
    boss_tokens: bossTokens,
    sessions
  };
  return world;
}
function normalizeModifierList(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }
  const out = [];
  for (const entry of raw) {
    if (typeof entry == "string") {
      const trimmed = entry.trim();
      if (trimmed) {
        out.push(trimmed);
      }
    }
  }
  return out;
}
function ensurePlayerWorld(state, now) {
  const world = normalizeWorld(state.world, now);
  state.world = world;
  return world;
}
function refreshWorldPlayer(world, now) {
  let changed = false;
  if (resetDailyEntries(world, now)) {
    changed = true;
  }
  if (regenWorldStamina(world, now)) {
    changed = true;
  }
  if (regenBossTickets(world, now)) {
    changed = true;
  }
  return changed;
}
function resetDailyEntries(world, now) {
  const resetMs = getWorldDailyResetMs();
  if (now - world.last_entry_reset_at >= resetMs) {
    world.daily_entries = 0;
    world.last_entry_reset_at = now;
    return true;
  }
  return false;
}
function regenWorldStamina(world, now) {
  const maxStamina = getWorldMaxStamina();
  const rechargeMs = getWorldStaminaRechargeMs();
  if (rechargeMs <= 0) {
    if (world.stamina != maxStamina) {
      world.stamina = maxStamina;
      world.last_stamina_at = now;
      return true;
    }
    return false;
  }
  const elapsed = now - world.last_stamina_at;
  if (elapsed <= 0) {
    return false;
  }
  const regen = Math.floor(elapsed / rechargeMs);
  if (regen <= 0) {
    return false;
  }
  world.stamina = Math.min(maxStamina, world.stamina + regen);
  world.last_stamina_at += regen * rechargeMs;
  if (world.stamina >= maxStamina) {
    world.last_stamina_at = now;
  }
  return true;
}
function regenBossTickets(world, now) {
  const maxTickets = getBossTicketMax();
  const rechargeMs = getBossTicketRechargeMs();
  if (rechargeMs <= 0) {
    if (world.boss_tickets != maxTickets) {
      world.boss_tickets = maxTickets;
      world.last_boss_ticket_at = now;
      return true;
    }
    return false;
  }
  const elapsed = now - world.last_boss_ticket_at;
  if (elapsed <= 0) {
    return false;
  }
  const regen = Math.floor(elapsed / rechargeMs);
  if (regen <= 0) {
    return false;
  }
  world.boss_tickets = Math.min(maxTickets, world.boss_tickets + regen);
  world.last_boss_ticket_at += regen * rechargeMs;
  if (world.boss_tickets >= maxTickets) {
    world.last_boss_ticket_at = now;
  }
  return true;
}
function ensureZoneProgress(world, zoneId, now) {
  let progress = world.zone_progress[zoneId];
  if (!progress) {
    progress = { heat: 0, reputation: 0, last_heat_at: now };
    world.zone_progress[zoneId] = progress;
    return progress;
  }
  decayZoneHeat(progress, now);
  return progress;
}
function decayZoneHeat(progress, now) {
  const decayPerHour = getWorldHeatDecayPerHour();
  if (decayPerHour <= 0) {
    return;
  }
  const elapsed = now - progress.last_heat_at;
  if (elapsed <= 0) {
    return;
  }
  const hours = elapsed / 3600000;
  const decay = Math.floor(hours * decayPerHour);
  if (decay <= 0) {
    return;
  }
  progress.heat = Math.max(0, progress.heat - decay);
  progress.last_heat_at = now;
}
function getWorldDailyEntryLimit() {
  return clampInt(getBalanceNumber("world_daily_entries", 10), 1, 1000);
}
function getWorldDailyResetMs() {
  const hours = getBalanceNumber("world_daily_reset_hours", 24);
  return Math.max(1, hours) * 3600 * 1000;
}
function getWorldMaxStamina() {
  return clampInt(getBalanceNumber("world_max_stamina", 12), 1, 1000);
}
function getWorldStaminaRechargeMs() {
  const seconds = getBalanceNumber("world_stamina_recharge_seconds", 300);
  return Math.max(0, seconds) * 1000;
}
function getWorldMaxBlocksPerAction() {
  return clampInt(getBalanceNumber("world_max_blocks_per_action", 4), 1, 100);
}
function getWorldHeatGain() {
  return clampInt(getBalanceNumber("world_heat_gain", 2), 0, 100);
}
function getWorldHeatMax() {
  return clampInt(getBalanceNumber("world_heat_max", 100), 1, 1e4);
}
function getWorldHeatDecayPerHour() {
  return getBalanceNumber("world_heat_decay_per_hour", 1);
}
function getWorldRotationMs() {
  const seconds = getBalanceNumber("world_rotation_seconds", 0);
  if (seconds > 0) {
    return seconds * 1000;
  }
  const hours = getBalanceNumber("world_rotation_hours", 24);
  return Math.max(1, hours) * 3600 * 1000;
}
function getWorldEntryFee() {
  return clampInt(getBalanceNumber("world_entry_fee_essence", 0), 0, 1e9);
}
function getBossTicketMax() {
  return clampInt(getBalanceNumber("boss_ticket_max", 5), 1, 999);
}
function getBossTicketRechargeMs() {
  const minutes = getBalanceNumber("boss_ticket_recharge_minutes", 30);
  return Math.max(0, minutes) * 60 * 1000;
}
function getBossAttackFee() {
  return clampInt(getBalanceNumber("boss_attack_fee_essence", 0), 0, 1e9);
}
function getBossIpLimitPerWindow() {
  return clampInt(getBalanceNumber("boss_ip_limit_per_window", 200), 0, 1e5);
}
function allowBossIp(ip, windowEnd) {
  const limit = getBossIpLimitPerWindow();
  if (!ip || limit <= 0) {
    return true;
  }
  const entry = bossIpWindow.get(ip);
  if (!entry || entry.windowEnd != windowEnd) {
    bossIpWindow.set(ip, { windowEnd, count: 1 });
    return true;
  }
  if (entry.count >= limit) {
    return false;
  }
  entry.count += 1;
  return true;
}
function cloneLabRuntime(runtime) {
  return normalizeLabRuntime(runtime ?? {});
}
function ensureLabRuntime(state) {
  if (!state.lab.runtime) {
    state.lab.runtime = { cooldowns: {}, boosts: {}, research: {} };
    return state.lab.runtime;
  }
  if (!state.lab.runtime.cooldowns) {
    state.lab.runtime.cooldowns = {};
  }
  if (!state.lab.runtime.boosts) {
    state.lab.runtime.boosts = {};
  }
  if (!state.lab.runtime.research) {
    state.lab.runtime.research = {};
  }
  return state.lab.runtime;
}
function cleanupLabRuntime(runtime, nowMs) {
  let changed = false;
  for (const [id, ts] of Object.entries(runtime.cooldowns)) {
    if (!Number.isFinite(ts) || ts <= nowMs) {
      delete runtime.cooldowns[id];
      changed = true;
    }
  }
  return changed;
}
function autoCompleteResearch(state, nowMs) {
  const runtime = ensureLabRuntime(state);
  let changed = false;
  for (let i = 0;i < 2; i++) {
    const research = runtime.research;
    const completesAt = research?.completes_at ?? 0;
    if (!research?.active_id || !Number.isFinite(completesAt) || completesAt <= 0 || completesAt > nowMs)
      break;
    const node = staticData.research[research.active_id];
    if (node?.flag_id)
      state.research_flags[node.flag_id] = true;
    const queued = research.queued_id ? staticData.research[research.queued_id] : undefined;
    runtime.research = queued ? { active_id: queued.id, started_at: completesAt, completes_at: completesAt + Math.max(1, queued.time_sec * (directiveActive(runtime, "research", completesAt) ? getBalanceNumber("hq_directive_research_time_mult", 0.9) : 1) * (isBoostActive(runtime, "fast_research", completesAt) ? experimentEffect("fast_research", "archive_time_mult", 0.85) : 1)) * 1000 } : {};
    changed = true;
  }
  return changed;
}
function canonicalHqPath(value, paths) {
  if (typeof value != "string") {
    return null;
  }
  for (const path of paths) {
    if (path.toLowerCase() == value.toLowerCase()) {
      return path;
    }
  }
  return null;
}
function clampAmount(value) {
  const num = typeof value == "number" ? value : Number(value ?? 0);
  if (!Number.isFinite(num)) {
    return 0;
  }
  const clamped = Math.max(0, Math.min(num, 1e9));
  return Math.floor(clamped);
}
function clampInt(value, min, max) {
  const num = typeof value == "number" ? value : Number(value ?? 0);
  if (!Number.isFinite(num)) {
    return min;
  }
  return Math.max(min, Math.min(Math.floor(num), max));
}
function cloneWallet(wallet) {
  return { ...wallet };
}
function computeWalletDelta(before, after) {
  const delta = {};
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  for (const key of keys) {
    const beforeVal = clampAmount(before[key] ?? 0);
    const afterVal = clampAmount(after[key] ?? 0);
    const diff = afterVal - beforeVal;
    if (diff != 0) {
      delta[key] = diff;
    }
  }
  return delta;
}
function hasWalletDelta(delta) {
  return Object.keys(delta).length > 0;
}
function auditWalletMutation(playerId, delta, reason, relatedId, ts) {
  if (!hasWalletDelta(delta)) {
    return;
  }
  const auditId = crypto.randomUUID();
  insertAuditStmt.run(auditId, playerId, JSON.stringify(delta), reason, relatedId, ts);
}
function getWalletCap(resourceId) {
  const caps = staticData.balance.wallet_caps;
  if (caps && typeof caps == "object" && caps[resourceId] != null) {
    const value = caps[resourceId];
    if (typeof value == "number" && Number.isFinite(value) && value > 0) {
      return Math.floor(value);
    }
  }
  const fallback = getBalanceNumber("wallet_max_per_resource", 1e9);
  return Math.max(1, Math.floor(fallback));
}
function getWalletInvariantError(wallet) {
  for (const [resId, amountRaw] of Object.entries(wallet)) {
    const amount = typeof amountRaw == "number" ? amountRaw : Number(amountRaw);
    if (!Number.isFinite(amount)) {
      return `Invalid wallet amount for ${resId}.`;
    }
    if (!Number.isInteger(amount)) {
      return `Wallet amount must be integer for ${resId}.`;
    }
    if (amount < 0) {
      return `Wallet amount negative for ${resId}.`;
    }
    const cap = getWalletCap(resId);
    if (amount > cap) {
      return `Wallet cap exceeded for ${resId}.`;
    }
  }
  return null;
}
function assertWalletInvariant(wallet) {
  const error = getWalletInvariantError(wallet);
  if (error) {
    throw new HttpError(400, error);
  }
}
function getSuspiciousAmountThreshold() {
  return clampInt(getBalanceNumber("wallet_suspicious_threshold", 5000000), 1, 1e9);
}
function isSuspiciousAmount(value) {
  return Math.abs(value) > getSuspiciousAmountThreshold();
}
function logSuspiciousAction(playerId, delta, reason, relatedId) {
  const now = Date.now();
  const tag = `SUSPICIOUS_${reason}`;
  auditWalletMutation(playerId, delta, tag, relatedId, now);
}
function checkSuspiciousDelta(playerId, delta, reason, relatedId) {
  for (const value of Object.values(delta)) {
    if (isSuspiciousAmount(value)) {
      logSuspiciousAction(playerId, delta, reason, relatedId);
      throw new HttpError(400, "Suspicious wallet delta.");
    }
  }
}
function rejectSuspiciousMarketBuy(buyerId, orderId, resourceId, priceResourceId, amount, unitPrice) {
  const totalPrice = unitPrice * amount;
  if (isSuspiciousAmount(amount) || isSuspiciousAmount(totalPrice)) {
    logSuspiciousAction(buyerId, {
      [String(priceResourceId || "essence")]: -totalPrice,
      [String(resourceId || "")]: amount
    }, "MARKET_BUY", orderId);
    throw new HttpError(400, "Suspicious buy amount.");
  }
}
var REACTOR_ROUTES = ["stable", "volatile", "mutagenic"];
var STORAGE_ROUTES = ["compact", "reactive", "sealed"];
var MARKET_STATUS_OPEN = "OPEN";
var MARKET_STATUS_FILLED = "FILLED";
var MARKET_STATUS_CANCELED = "CANCELED";
var MARKET_TYPE_SELL = "SELL";
var MARKET_TYPE_BUY = "BUY";
var MARKET_MAX_AMOUNT = 1e6;
var MARKET_MAX_PRICE = 1e9;
var MARKET_LIST_LIMIT = 200;
var TRADE_JOB_STATUS_OPEN = "OPEN";
var TRADE_JOB_STATUS_CLOSED = "CLOSED";
var TRADE_RUN_STATUS_PENDING = "PENDING";
var TRADE_RUN_STATUS_CLAIMED = "CLAIMED";
var TRADE_MAX_AMOUNT = 1e6;
var TRADE_MAX_DURATION_SEC = 7 * 24 * 3600;
var TRADE_MAX_QUEUE = 100;
var TRADE_LIST_LIMIT = 200;
var HQ_RULES = {
  lab_th: { unlock: 1, max: 10, cap_per_hq: 1 },
  essence_reactor: { unlock: 1, max: 10, cap_per_hq: 1 },
  storage_vault: { unlock: 1, max: 10, cap_per_hq: 1 },
  build_forge: { unlock: 1, max: 10, cap_per_hq: 1 },
  homunculus_vat: { unlock: 2, max: 10, cap_per_hq: 1 },
  ultrahit_tower: { unlock: 2, max: 10, cap_per_hq: 1 },
  experiment_chamber: { unlock: 3, max: 10, cap_per_hq: 1 },
  arcane_archives: { unlock: 3, max: 10, cap_per_hq: 1 },
  sync_nexus: { unlock: 4, max: 10, cap_per_hq: 1 },
  anomaly_containment: { unlock: 5, max: 10, cap_per_hq: 1 },
  trade_hall: { unlock: 2, max: 10, cap_per_hq: 1 },
  world_gate: { unlock: 1, max: 10, cap_per_hq: 1 }
};
var experimentCatalog = readJsonFile(resolve2(import.meta.dir, "..", "..", "data", "static", "experiments.json"));
var EXPERIMENTS = Object.fromEntries((Array.isArray(experimentCatalog?.experiments) ? experimentCatalog.experiments : []).filter((entry) => typeof entry?.id === "string").map((entry) => [entry.id, entry]));
function experimentEffect(id, key, fallback) {
  const value = EXPERIMENTS[id]?.effect?.[key];
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function applyUpgrade(state, payload, debugBypass = false) {
  const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
  if (!buildingId || buildingId.length > 64) {
    return { state, error: "Invalid building_id." };
  }
  if (!staticData.buildings[buildingId]) {
    return { state, error: "Unknown building_id." };
  }
  const current = ensureBuildingState(state, buildingId);
  if (!debugBypass && !canUpgrade(buildingId, current.level, state.lab.hqLevel)) {
    return { state, error: "Upgrade cap reached." };
  }
  const rule = HQ_RULES[buildingId] ?? { unlock: 1, max: 10, cap_per_hq: 1 };
  if (current.level >= rule.max) {
    return { state, error: "Upgrade cap reached." };
  }
  const targetLevel = current.level + 1;
  if (!debugBypass) {
    const cost = resolveUpgradeCost(buildingId, targetLevel, state.lab.hqPath);
    if (!cost.ok) {
      return { state, error: cost.error || "Missing cost data." };
    }
    const wallet = state.wallet;
    for (const [resId, amount] of Object.entries(cost.cost)) {
      if (!staticData.resources.has(resId)) {
        return { state, error: "Unknown resource id in cost." };
      }
      if ((wallet[resId] ?? 0) < amount) {
        return { state, error: "Insufficient resources." };
      }
    }
    for (const [resId, amount] of Object.entries(cost.cost)) {
      wallet[resId] = (wallet[resId] ?? 0) - amount;
      if (wallet[resId] < 0) {
        wallet[resId] = 0;
      }
    }
  }
  current.level = targetLevel;
  if (buildingId == "lab_th" && state.lab.hqLevel < targetLevel) {
    state.lab.hqLevel = targetLevel;
  }
  return { state };
}
function applyRouteChange(state, payload) {
  const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
  const routeRaw = typeof payload?.route == "string" ? payload.route.trim() : "";
  if (!buildingId || !routeRaw) {
    return { state, error: "Invalid building_id or route." };
  }
  if (!staticData.buildings[buildingId]) {
    return { state, error: "Unknown building_id." };
  }
  const routeKey = routeRaw.toLowerCase();
  if (buildingId == "lab_th") {
    const hqPath = canonicalHqPath(routeRaw, staticData.hqPaths);
    if (!hqPath) {
      return { state, error: "Invalid HQ path." };
    }
    state.lab.hqPath = hqPath;
    const labState = ensureBuildingState(state, buildingId);
    labState.route = hqPath;
    return { state };
  }
  const allowed = getAllowedRoutes(buildingId);
  if (!allowed.includes(routeKey)) {
    return { state, error: "Invalid route." };
  }
  const building = ensureBuildingState(state, buildingId);
  building.route = routeKey;
  return { state };
}
function applyClaim(state, payload, nowMs) {
  const buildingId = typeof payload?.building_id == "string" ? payload.building_id.trim() : "";
  if (!buildingId) {
    return { state, error: "Invalid building_id." };
  }
  if (!staticData.buildings[buildingId]) {
    return { state, error: "Unknown building_id." };
  }
  if (buildingId != "essence_reactor") {
    return { state, error: "Building has no production." };
  }
  const reactor = ensureBuildingState(state, "essence_reactor");
  const storage = ensureBuildingState(state, "storage_vault");
  const runtime = ensureLabRuntime(state);
  cleanupLabRuntime(runtime, nowMs);
  tickProduction(reactor, nowMs, reactor.level, reactor.route || "stable", storage.route || "", state.lab.hqPath, runtime);
  const capacity = Math.floor(computeCapacity(storage.level, storage.route || "", state.lab.hqPath) * (isBoostActive(runtime, "extra_storage", nowMs) ? experimentEffect("extra_storage", "capacity_mult", 1.15) : 1));
  const claimResult = claimProduction(reactor, capacity, reactor.route || "stable", storage.route || "", state.lab.hqPath, runtime, nowMs);
  applyWalletGrant(state.wallet, claimResult.grants);
  const overcharge = runtime.reactor_overcharge ?? { progress: 0, last_used_at: 0 };
  overcharge.progress = Math.min(Math.max(1, Math.trunc(getBalanceNumber("reactor_overcharge_threshold", 300))), overcharge.progress + (claimResult.grants.essence ?? 0));
  runtime.reactor_overcharge = overcharge;
  return { state };
}
function applyStartExperiment(state, payload, clientActionId, nowMs) {
  const experimentId = typeof payload?.experiment_id == "string" ? payload.experiment_id.trim() : "";
  if (!experimentId || experimentId.length > 64) {
    return { state, error: "Invalid experiment_id." };
  }
  const experiment = EXPERIMENTS[experimentId];
  if (!experiment) {
    return { state, error: "Unknown experiment_id." };
  }
  if (experiment.kind !== "boost" || experiment.boost_id !== experimentId || !Number.isFinite(experiment.success_chance) || experiment.success_chance < 0 || experiment.success_chance > 1 || !Number.isSafeInteger(experiment.cooldown_s) || experiment.cooldown_s < 0 || !Number.isSafeInteger(experiment.boost_duration_s) || experiment.boost_duration_s <= 0 || !experiment.cost || typeof experiment.cost !== "object" || Array.isArray(experiment.cost))
    return { state, error: "Invalid experiment configuration." };
  const unlockLevel = HQ_RULES.experiment_chamber?.unlock ?? 1;
  if (state.lab.hqLevel < unlockLevel) {
    return { state, error: "Experiment Chamber locked." };
  }
  const chamber = ensureBuildingState(state, "experiment_chamber");
  if (chamber.level <= 0) {
    return { state, error: "Experiment Chamber not built." };
  }
  const runtime = ensureLabRuntime(state);
  cleanupLabRuntime(runtime, nowMs);
  const cooldownUntil = runtime.cooldowns[experimentId] ?? 0;
  if (cooldownUntil > nowMs || isBoostActive(runtime, experimentId, nowMs)) {
    return { state, error: "Experiment on cooldown." };
  }
  for (const [resId, amountRaw] of Object.entries(experiment.cost)) {
    if (!staticData.resources.has(resId) || !Number.isSafeInteger(amountRaw) || amountRaw < 0) {
      return { state, error: "Unknown resource id in experiment cost." };
    }
    const amount = clampAmount(amountRaw);
    if ((state.wallet[resId] ?? 0) < amount) {
      return { state, error: "Insufficient resources." };
    }
  }
  for (const [resId, amountRaw] of Object.entries(experiment.cost)) {
    const amount = clampAmount(amountRaw);
    state.wallet[resId] = (state.wallet[resId] ?? 0) - amount;
    if (state.wallet[resId] < 0) {
      state.wallet[resId] = 0;
    }
  }
  const stability = runtime.experiment_stability ?? { failures: 0 };
  const chance = clampChance((experiment.success_chance ?? 0) + stability.failures * 0.1 + (directiveActive(runtime, "experimentation", nowMs) ? getBalanceNumber("hq_directive_experiment_chance_bonus", 0.05) : 0) + (experimentId !== "better_odds" && isBoostActive(runtime, "better_odds", nowMs) ? experimentEffect("better_odds", "experiment_chance_bonus", 0.1) : 0));
  const success = chance >= 1 || seededRandom01(`${EXPERIMENT_SECRET}:${clientActionId}:${experimentId}:success`) < chance;
  stability.failures = success ? 0 : Math.min(3, stability.failures + 1);
  runtime.experiment_stability = stability;
  const expiresAt = success ? nowMs + Math.max(0, experiment.boost_duration_s ?? 0) * 1000 : 0;
  if (success) {
    if (["volatile_overclock", "essence_turbo"].includes(experimentId)) {
      const reactor = ensureBuildingState(state, "essence_reactor");
      const storage = ensureBuildingState(state, "storage_vault");
      if (reactor.level > 0)
        tickProduction(reactor, nowMs, reactor.level, reactor.route || "stable", storage.route || "", state.lab.hqPath, runtime);
    }
    runtime.boosts[experiment.boost_id ?? experimentId] = { started_at: nowMs, expires_at: expiresAt };
  }
  runtime.experiment_last = { id: experimentId, success, chance, at: nowMs, expires_at: expiresAt };
  const cooldownS = Math.max(0, experiment.cooldown_s ?? 0);
  if (cooldownS > 0) {
    runtime.cooldowns[experimentId] = nowMs + cooldownS * 1000;
  }
  return { state };
}
function applyStartResearch(state, payload, nowMs) {
  const researchId = typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
  if (!researchId || researchId.length > 64) {
    return { state, error: "Invalid research_id." };
  }
  const node = staticData.research[researchId];
  if (!node) {
    return { state, error: "Unknown research_id." };
  }
  if (state.research_flags[node.flag_id]) {
    return { state, error: "Research already completed." };
  }
  const unlockLevel = HQ_RULES.arcane_archives?.unlock ?? 1;
  if (state.lab.hqLevel < unlockLevel) {
    return { state, error: "Arcane Archives locked." };
  }
  const archives = ensureBuildingState(state, "arcane_archives");
  if (archives.level <= 0) {
    return { state, error: "Arcane Archives not built." };
  }
  const runtime = ensureLabRuntime(state);
  cleanupLabRuntime(runtime, nowMs);
  autoCompleteResearch(state, nowMs);
  const active = runtime.research?.active_id ?? "";
  if (active) {
    return { state, error: "Research already in progress." };
  }
  for (const req of node.requires) {
    if (!state.research_flags[req]) {
      return { state, error: "Research requirements not met." };
    }
  }
  for (const [resId, amountRaw] of Object.entries(node.cost)) {
    if (!staticData.resources.has(resId)) {
      return { state, error: "Unknown resource id in research cost." };
    }
    const amount = clampAmount(amountRaw);
    if ((state.wallet[resId] ?? 0) < amount) {
      return { state, error: "Insufficient resources." };
    }
  }
  for (const [resId, amountRaw] of Object.entries(node.cost)) {
    const amount = clampAmount(amountRaw);
    state.wallet[resId] = (state.wallet[resId] ?? 0) - amount;
    if (state.wallet[resId] < 0) {
      state.wallet[resId] = 0;
    }
  }
  runtime.research = {
    active_id: researchId,
    started_at: nowMs,
    completes_at: nowMs + Math.max(1, node.time_sec * (directiveActive(runtime, "research", nowMs) ? getBalanceNumber("hq_directive_research_time_mult", 0.9) : 1) * (isBoostActive(runtime, "fast_research", nowMs) ? experimentEffect("fast_research", "archive_time_mult", 0.85) : 1)) * 1000
  };
  return { state };
}
function applyClaimResearch(state, payload, nowMs) {
  const runtime = ensureLabRuntime(state);
  autoCompleteResearch(state, nowMs);
  const requested = typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
  if (requested && staticData.research[requested] && state.research_flags[staticData.research[requested].flag_id])
    return { state };
  const activeId = runtime.research?.active_id ?? "";
  if (!activeId) {
    const requested2 = typeof payload?.research_id == "string" ? payload.research_id.trim() : "";
    if (requested2) {
      const node2 = staticData.research[requested2];
      if (node2 && state.research_flags[node2.flag_id]) {
        return { state };
      }
    }
    return { state, error: "No research in progress." };
  }
  if (requested && requested != activeId) {
    return { state, error: "Research mismatch." };
  }
  const completesAt = runtime.research?.completes_at ?? 0;
  if (!Number.isFinite(completesAt) || completesAt > nowMs) {
    return { state, error: "Research not complete." };
  }
  const node = staticData.research[activeId];
  if (node && node.flag_id) {
    state.research_flags[node.flag_id] = true;
  }
  runtime.research = {};
  return { state };
}
function seededRandom01(seed) {
  const hash = createHash("sha256").update(seed).digest();
  const value = hash.readUInt32BE(0);
  return value / 4294967295;
}
function getBoostMultipliers(labRuntime, nowMs) {
  const active = getActiveBoosts(labRuntime, nowMs);
  const outputMult = Math.max(1, active.overclock ? experimentEffect("volatile_overclock", "reactor_output_mult", 1.1) : 1, isBoostActive(labRuntime, "essence_turbo", nowMs) ? experimentEffect("essence_turbo", "reactor_output_mult", 1.2) : 1);
  const lossChanceMult = isBoostActive(labRuntime, "safe_reactor", nowMs) ? experimentEffect("safe_reactor", "volatile_loss_mult", 0.65) : 1;
  const rareChanceMult = active.mutagen ? experimentEffect("mutagen_surge", "rare_chance_mult", 1.35) : 1;
  return { outputMult, lossChanceMult, rareChanceMult };
}
function getActiveBoosts(labRuntime, nowMs) {
  const overclock = isBoostActive(labRuntime, "volatile_overclock", nowMs);
  const mutagen = isBoostActive(labRuntime, "mutagen_surge", nowMs);
  return { overclock, mutagen };
}
function isBoostActive(labRuntime, boostId, nowMs) {
  const entry = labRuntime.boosts[boostId];
  if (!entry) {
    return false;
  }
  const expiresAt = entry.expires_at ?? 0;
  return Number.isFinite(expiresAt) && (entry.started_at ?? 0) <= nowMs && expiresAt > nowMs;
}
function applyWalletGrant(wallet, grants) {
  for (const [resId, amountRaw] of Object.entries(grants)) {
    if (!staticData.resources.has(resId)) {
      continue;
    }
    const amount = clampAmount(amountRaw);
    wallet[resId] = (wallet[resId] ?? 0) + amount;
  }
}
function ensureBuildingState(state, id) {
  if (!state.lab.buildings[id]) {
    state.lab.buildings[id] = { level: 0, route: "", runtime: {} };
  }
  const entry = state.lab.buildings[id];
  if (!entry.runtime) {
    entry.runtime = {};
  }
  if (entry.runtime.stored_output == null) {
    entry.runtime.stored_output = 0;
  }
  if (entry.runtime.last_tick == null) {
    entry.runtime.last_tick = Date.now();
  }
  return entry;
}
function canUpgrade(buildingId, currentLevel, hqLevel) {
  const rule = HQ_RULES[buildingId] ?? { unlock: 1, max: 10, cap_per_hq: 1 };
  if (hqLevel < rule.unlock) {
    return false;
  }
  if (buildingId == "lab_th") {
    return currentLevel < rule.max;
  }
  const cap = Math.min(rule.max, Math.max(0, hqLevel) * Math.max(1, rule.cap_per_hq));
  return currentLevel < cap;
}
function resolveUpgradeCost(buildingId, level, hqPath) {
  const entry = staticData.buildings[buildingId];
  if (!entry || typeof entry != "object") {
    return { ok: false, cost: {}, error: "Unknown building." };
  }
  const costs = entry.costs;
  if (!costs || typeof costs != "object") {
    return { ok: false, cost: {}, error: "Missing cost data." };
  }
  const costEntry = costs[String(level)];
  if (!costEntry || typeof costEntry != "object") {
    return { ok: false, cost: {}, error: "Missing cost data." };
  }
  const mult = getHqCostMultiplier(hqPath);
  const out = {};
  for (const [key, value] of Object.entries(costEntry)) {
    const amount = clampAmount(value);
    out[key] = Math.floor(amount * mult);
  }
  return { ok: true, cost: out };
}
function getHqCostMultiplier(hqPath) {
  const key = hqPath.toLowerCase();
  const map = staticData.balance.hq_cost_mult ?? {
    scientific: 0.95,
    chaotic: 1.05,
    industrial: 1
  };
  return getMultiplier(map, key, 1);
}
function getAllowedRoutes(buildingId) {
  if (buildingId == "essence_reactor") {
    return REACTOR_ROUTES;
  }
  if (buildingId == "storage_vault") {
    return STORAGE_ROUTES;
  }
  const entry = staticData.buildings[buildingId];
  if (entry && Array.isArray(entry.routes)) {
    return entry.routes.map((value) => value.toLowerCase());
  }
  return [];
}
function computeCapacity(storageLevel, storageRoute, hqPath) {
  const base = getBalanceNumber("storage_base_capacity", 1000);
  const perLevel = getBalanceNumber("storage_capacity_per_level", 250);
  const level = Math.max(0, storageLevel);
  const routeMults = staticData.balance.storage_route_capacity_mult ?? {
    compact: 1,
    reactive: 1.1,
    sealed: 0.9
  };
  const hqMults = staticData.balance.hq_capacity_mult ?? {
    scientific: 1.05,
    chaotic: 1,
    industrial: 1.1
  };
  const routeMult = getMultiplier(routeMults, storageRoute.toLowerCase(), 1);
  const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1);
  return Math.floor(Math.max(0, (base + perLevel * level) * routeMult * hqMult));
}
function directiveActive(runtime, id, at) {
  const directive = runtime.directive;
  return !!directive && directive.id === id && directive.starts_at <= at && at < directive.ends_at;
}
function tickProduction(building, nowMs, level, route, storageRoute, hqPath, labRuntime) {
  if (!building.runtime) {
    building.runtime = {};
  }
  const runtime = building.runtime;
  const lastTick = typeof runtime.last_tick == "number" ? runtime.last_tick : nowMs;
  if (nowMs < lastTick) {
    runtime.last_tick = nowMs;
    return;
  }
  let delta = nowMs - lastTick;
  const capHours = getBalanceNumber("offline_cap_hours", 12);
  const capMs = capHours * 3600 * 1000;
  if (capMs > 0 && delta > capMs) {
    delta = capMs;
  }
  if (delta <= 0) {
    runtime.last_tick = nowMs;
    return;
  }
  const end = nowMs;
  const start = end - delta;
  const boundaries = [start, end];
  for (const period of [labRuntime.directive, labRuntime.boosts.volatile_overclock, labRuntime.boosts.essence_turbo]) {
    if (!period)
      continue;
    const interval = period;
    for (const point of [interval.started_at ?? interval.starts_at ?? 0, interval.expires_at ?? interval.ends_at ?? 0])
      if (point > start && point < end)
        boundaries.push(point);
  }
  boundaries.sort((a, b2) => a - b2);
  let produced = 0;
  for (let i = 1;i < boundaries.length; i++) {
    const from = boundaries[i - 1], to = boundaries[i], sample = from + (to - from) / 2;
    produced += computeOutputRate(level, route, storageRoute, hqPath, labRuntime, sample) * (to - from) / 1000 * (directiveActive(labRuntime, "production", sample) ? getBalanceNumber("hq_directive_production_mult", 1.1) : 1);
  }
  runtime.stored_output = Math.max(0, (runtime.stored_output ?? 0) + produced);
  runtime.last_tick = nowMs;
}
function computeOutputRate(level, route, storageRoute, hqPath, labRuntime, nowMs) {
  const base = getBalanceNumber("reactor_base_rate", 1);
  const perLevel = getBalanceNumber("reactor_rate_per_level", 0.2);
  const routeMults = staticData.balance.reactor_route_output_mult ?? {
    stable: 0.8,
    volatile: 1.35,
    mutagenic: 0.65
  };
  const storageMults = staticData.balance.storage_route_output_mult ?? {
    reactive: 1.05
  };
  const hqMults = staticData.balance.route_multipliers ?? staticData.balance.hq_output_mult ?? {
    scientific: 1.05,
    chaotic: 1,
    industrial: 0.95
  };
  const lvl = Math.max(0, level);
  const baseRate = base + perLevel * lvl;
  const routeMult = getMultiplier(routeMults, route.toLowerCase(), 1);
  const storageMult = getMultiplier(storageMults, storageRoute.toLowerCase(), 1);
  const hqMult = getMultiplier(hqMults, hqPath.toLowerCase(), 1);
  const boosts = getBoostMultipliers(labRuntime, nowMs);
  return Math.max(0, baseRate * routeMult * storageMult * hqMult * boosts.outputMult);
}
function claimProduction(building, capacity, route, storageRoute, hqPath, labRuntime, nowMs) {
  if (!building.runtime) {
    building.runtime = {};
  }
  const runtime = building.runtime;
  const available = Math.max(0, runtime.stored_output ?? 0);
  const cap = Math.max(0, capacity);
  const claimable = Math.min(available, cap);
  const boosts = getBoostMultipliers(labRuntime, nowMs);
  let loss = 0;
  if (route.toLowerCase() == "volatile" && claimable > 0) {
    let lossChance = getBalanceNumber("volatile_loss_chance", 0.25);
    lossChance *= getMultiplier(staticData.balance.hq_risk_mult ?? { scientific: 0.9, chaotic: 1.1, industrial: 0.85 }, hqPath.toLowerCase(), 1);
    lossChance *= boosts.lossChanceMult;
    lossChance = clampChance(lossChance);
    if (Math.random() < lossChance) {
      let lossPct = getBalanceNumber("volatile_loss_pct", 0.3);
      if (storageRoute.toLowerCase() == "compact") {
        lossPct *= getBalanceNumber("compact_loss_mult", 0.5);
      }
      lossPct = clampChance(lossPct);
      loss = claimable * lossPct;
    }
  }
  const claimed = Math.max(0, claimable - loss);
  runtime.stored_output = Math.max(0, available - claimable);
  const grants = { essence: Math.floor(claimed) };
  if (route.toLowerCase() == "mutagenic" && claimed > 0) {
    const rareChance = getMutagenicRareChance(storageRoute, hqPath, boosts.rareChanceMult);
    if (Math.random() < rareChance) {
      grants.arcane_shard = 1;
    }
  }
  return { grants };
}
function getMutagenicRareChance(storageRoute, hqPath, boostMult = 1) {
  let chance = getBalanceNumber("mutagenic_rare_base_chance", 0.08);
  if (storageRoute.toLowerCase() == "sealed") {
    chance *= getBalanceNumber("sealed_rare_mult", 1.25);
  }
  const hqRare = staticData.balance.hq_rare_mult ?? { scientific: 0.9, chaotic: 1.1, industrial: 0.85 };
  chance *= getMultiplier(hqRare, hqPath.toLowerCase(), 1);
  chance *= boostMult;
  const cap = getBalanceNumber("mutagenic_rare_cap", 0.25);
  return clampChance(Math.min(chance, cap));
}
function getBalanceNumber(key, fallback) {
  const value = staticData.balance[key];
  if (typeof value == "number" && Number.isFinite(value)) {
    return value;
  }
  return fallback;
}
function getMultiplier(map, key, fallback) {
  if (map && typeof map == "object" && map[key] != null) {
    const value = map[key];
    if (typeof value == "number" && Number.isFinite(value)) {
      return value;
    }
  }
  if (map && typeof map == "object") {
    for (const [mapKey, value] of Object.entries(map)) {
      if (mapKey.toLowerCase() == key.toLowerCase()) {
        if (typeof value == "number" && Number.isFinite(value)) {
          return value;
        }
      }
    }
  }
  return fallback;
}
function clampChance(value) {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.max(0, Math.min(value, 1));
}
function getMarketFeeBps() {
  return clampInt(getBalanceNumber("market_fee_bps", 200), 0, 1e4);
}
function ensureWorldState(now) {
  const row = getWorldStmt.get();
  const parsed = parseWorldState(row?.state_json);
  let changed = false;
  let state = parsed ?? createDefaultWorldState(now);
  if (!parsed) {
    changed = true;
  }
  const normalized = normalizeWorldState(state, now);
  state = normalized.state;
  changed = changed || normalized.changed;
  if (changed) {
    state.updated_at = now;
    if (row) {
      updateWorldStmt.run(JSON.stringify(state), now);
    } else {
      insertWorldStmt.run(JSON.stringify(state), now);
    }
  }
  return state;
}
function parseWorldState(stateJson) {
  if (!stateJson) {
    return null;
  }
  try {
    const parsed = JSON.parse(stateJson);
    if (!parsed || typeof parsed != "object") {
      return null;
    }
    const zones = Array.isArray(parsed.zones) ? parsed.zones : [];
    const activeEvents = Array.isArray(parsed.active_events) ? parsed.active_events : [];
    const bosses = Array.isArray(parsed.bosses) ? parsed.bosses : [];
    const updatedAt = clampInt(parsed.updated_at ?? 0, 0, Number.MAX_SAFE_INTEGER);
    return {
      zones,
      active_events: activeEvents,
      bosses,
      updated_at: updatedAt
    };
  } catch {
    return null;
  }
}
function normalizeWorldState(state, now) {
  let changed = false;
  const zoneMap = new Map;
  if (Array.isArray(state.zones)) {
    for (const entry of state.zones) {
      if (!entry || typeof entry.zone_id != "string") {
        changed = true;
        continue;
      }
      const zoneId = entry.zone_id.trim();
      if (!zoneId || zoneMap.has(zoneId)) {
        changed = true;
        continue;
      }
      zoneMap.set(zoneId, {
        zone_id: zoneId,
        modifier_ids: normalizeModifierList(entry.modifier_ids),
        rotation_ends_at: clampInt(entry.rotation_ends_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
        seed: typeof entry.seed == "string" ? entry.seed : ""
      });
    }
  } else {
    changed = true;
  }
  const zones = [];
  const rotationMs = getWorldRotationMs();
  const zoneDefs = Object.values(staticData.zones);
  for (const zone of zoneDefs) {
    let entry = zoneMap.get(zone.id);
    if (!entry) {
      entry = createZoneRotation(zone, now, rotationMs);
      changed = true;
    } else if (!entry.seed) {
      entry.seed = createZoneSeed(zone.id, now);
      changed = true;
    }
    if (!Number.isFinite(entry.rotation_ends_at) || entry.rotation_ends_at <= now) {
      entry = createZoneRotation(zone, now, rotationMs);
      changed = true;
    } else {
      const sanitized = sanitizeModifierIds(entry.modifier_ids, zone);
      if (sanitized.length != entry.modifier_ids.length) {
        entry.modifier_ids = sanitized;
        changed = true;
      }
    }
    zones.push(entry);
  }
  const activeEvents = Array.isArray(state.active_events) ? state.active_events : [];
  if (!Array.isArray(state.active_events)) {
    changed = true;
  }
  const bossMap = new Map;
  if (Array.isArray(state.bosses)) {
    for (const entry of state.bosses) {
      if (!entry || typeof entry.boss_id != "string") {
        changed = true;
        continue;
      }
      const bossId = entry.boss_id.trim();
      if (!bossId || bossMap.has(bossId)) {
        changed = true;
        continue;
      }
      const contributors = entry.contributors && typeof entry.contributors == "object" ? entry.contributors : {};
      bossMap.set(bossId, {
        boss_id: bossId,
        hp: clampInt(entry.hp ?? 0, 0, Number.MAX_SAFE_INTEGER),
        max_hp: clampInt(entry.max_hp ?? 0, 0, Number.MAX_SAFE_INTEGER),
        phase: clampInt(entry.phase ?? 1, 1, 99),
        window_starts_at: clampInt(entry.window_starts_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
        window_ends_at: clampInt(entry.window_ends_at ?? 0, 0, Number.MAX_SAFE_INTEGER),
        modifiers: normalizeModifierList(entry.modifiers),
        contributors
      });
    }
  } else {
    changed = true;
  }
  const bosses = [];
  const bossDefs = Object.values(staticData.bosses);
  for (const boss of bossDefs) {
    let entry = bossMap.get(boss.id);
    if (!entry) {
      entry = createBossState(boss, now);
      changed = true;
    } else {
      const normalized = normalizeBossState(entry, boss, now);
      entry = normalized.boss;
      if (normalized.changed) {
        changed = true;
      }
    }
    bosses.push(entry);
  }
  return {
    state: {
      zones,
      active_events: activeEvents,
      bosses,
      updated_at: state.updated_at ?? now
    },
    changed
  };
}
function createDefaultWorldState(now) {
  const rotationMs = getWorldRotationMs();
  const zones = [];
  for (const zone of Object.values(staticData.zones)) {
    zones.push(createZoneRotation(zone, now, rotationMs));
  }
  const bosses = [];
  for (const boss of Object.values(staticData.bosses)) {
    bosses.push(createBossState(boss, now));
  }
  return {
    zones,
    active_events: [],
    bosses,
    updated_at: now
  };
}
function createZoneRotation(zone, now, rotationMs) {
  const seed = createZoneSeed(zone.id, now);
  const modifierIds = rollZoneModifiers(zone, seed);
  return {
    zone_id: zone.id,
    modifier_ids: modifierIds,
    rotation_ends_at: now + rotationMs,
    seed
  };
}
function createZoneSeed(zoneId, now) {
  return createHash("sha256").update(`${WORLD_SECRET}:${zoneId}:${now}`).digest("hex");
}
function sanitizeModifierIds(raw, zone) {
  const allow = Array.isArray(zone.modifiers) ? zone.modifiers : [];
  if (allow.length == 0) {
    return raw.filter((value) => value && value.trim().length > 0);
  }
  const allowed = new Set(allow.map((value) => value.trim()).filter((value) => value.length > 0));
  return raw.filter((value) => value && allowed.has(value.trim()));
}
function rollZoneModifiers(zone, seed) {
  const list = Array.isArray(zone.modifiers) ? zone.modifiers.map((value) => value.trim()).filter((value) => value.length > 0) : [];
  if (list.length == 0) {
    return [];
  }
  const desired = clampInt(getBalanceNumber("world_modifiers_per_zone", 1), 0, list.length);
  if (desired <= 0) {
    return [];
  }
  const pool = list.slice();
  const selected = [];
  for (let i = 0;i < desired; i++) {
    const roll = seededRandom01(`${seed}:mod:${i}`);
    const idx = Math.min(pool.length - 1, Math.floor(roll * pool.length));
    selected.push(pool.splice(idx, 1)[0]);
    if (pool.length == 0) {
      break;
    }
  }
  return selected;
}
function createBossState(boss, now) {
  const maxHp = getBossMaxHp(boss);
  const window2 = getBossWindowTimes(boss.id, now);
  const seed = createHash("sha256").update(`${WORLD_SECRET}:boss:${boss.id}:${window2.start}`).digest("hex");
  const modifiers = rollBossModifiers(boss, seed);
  return {
    boss_id: boss.id,
    hp: maxHp,
    max_hp: maxHp,
    phase: 1,
    window_starts_at: window2.start,
    window_ends_at: window2.end,
    modifiers,
    contributors: {}
  };
}
function normalizeBossState(entry, boss, now) {
  let changed = false;
  let bossState = { ...entry };
  const maxHp = getBossMaxHp(boss);
  if (bossState.max_hp <= 0 || bossState.max_hp != maxHp) {
    bossState.max_hp = maxHp;
    if (bossState.hp > maxHp) {
      bossState.hp = maxHp;
    }
    changed = true;
  }
  const window2 = getBossWindowTimes(boss.id, now);
  const windowInvalid = bossState.window_ends_at <= now || bossState.window_starts_at != window2.start || bossState.window_ends_at != window2.end;
  if (windowInvalid) {
    bossState = createBossState(boss, now);
    changed = true;
  } else {
    const sanitized = sanitizeBossModifiers(bossState.modifiers, boss);
    if (sanitized.length != bossState.modifiers.length) {
      bossState.modifiers = sanitized;
      changed = true;
    }
    bossState.phase = computeBossPhase(bossState.hp, bossState.max_hp);
  }
  return { boss: bossState, changed };
}
function getBossWindowTimes(bossId, now) {
  const intervalMs = getBossIntervalMs();
  const windowMs = getBossWindowMs();
  const offsetLimit = Math.max(1, intervalMs - windowMs);
  const hash = createHash("sha256").update(`${WORLD_SECRET}:boss_offset:${bossId}`).digest();
  const offsetRaw = hash.readUInt32BE(0) % offsetLimit;
  const base = Math.floor((now - offsetRaw) / intervalMs) * intervalMs + offsetRaw;
  return { start: base, end: base + windowMs };
}
function getBossIntervalMs() {
  const minutes = getBalanceNumber("boss_interval_minutes", 120);
  return Math.max(1, minutes) * 60 * 1000;
}
function getBossWindowMs() {
  const minutes = getBalanceNumber("boss_window_minutes", 15);
  return Math.max(1, minutes) * 60 * 1000;
}
function getBossMaxHp(boss) {
  const map = staticData.balance.boss_hp;
  if (map && typeof map == "object" && map[boss.id] != null) {
    const value = map[boss.id];
    if (typeof value == "number" && Number.isFinite(value) && value > 0) {
      return Math.floor(value);
    }
  }
  const base = getBalanceNumber("boss_base_hp", boss.max_hp ?? 50000);
  const multMap = staticData.balance.boss_hp_mult;
  if (multMap && typeof multMap == "object" && multMap[boss.id] != null) {
    const mult = multMap[boss.id];
    if (typeof mult == "number" && Number.isFinite(mult) && mult > 0) {
      return Math.floor(base * mult);
    }
  }
  return Math.max(1, Math.floor(base));
}
function sanitizeBossModifiers(raw, boss) {
  const allow = Array.isArray(boss.modifiers) ? boss.modifiers : [];
  if (allow.length == 0) {
    return raw.filter((value) => value && value.trim().length > 0);
  }
  const allowed = new Set(allow.map((value) => value.trim()).filter((value) => value.length > 0));
  return raw.filter((value) => value && allowed.has(value.trim()));
}
function rollBossModifiers(boss, seed) {
  const list = Array.isArray(boss.modifiers) ? boss.modifiers.map((value) => value.trim()).filter((value) => value.length > 0) : [];
  const pool = list.length > 0 ? list : getBossModifierPool();
  if (pool.length == 0) {
    return [];
  }
  const desired = clampInt(getBalanceNumber("boss_modifiers_per_window", 1), 0, pool.length);
  if (desired <= 0) {
    return [];
  }
  const pickPool = pool.slice();
  const selected = [];
  for (let i = 0;i < desired; i++) {
    const roll = seededRandom01(`${seed}:boss_mod:${i}`);
    const idx = Math.min(pickPool.length - 1, Math.floor(roll * pickPool.length));
    selected.push(pickPool.splice(idx, 1)[0]);
    if (pickPool.length == 0) {
      break;
    }
  }
  return selected;
}
function getBossModifierPool() {
  const pool = staticData.balance.boss_modifier_pool;
  if (Array.isArray(pool)) {
    return pool.map((value) => typeof value == "string" ? value.trim() : "").filter((value) => value.length > 0);
  }
  return ["feral_rage", "arcane_flux", "void_surge"];
}
function computeBossPhase(hp, maxHp) {
  if (maxHp <= 0) {
    return 1;
  }
  if (hp <= 0) {
    return getBossPhaseThresholds().length + 1;
  }
  const ratio = hp / maxHp;
  const thresholds = getBossPhaseThresholds();
  let phase = 1;
  for (let i = 0;i < thresholds.length; i++) {
    if (ratio <= thresholds[i]) {
      phase = i + 2;
    }
  }
  return Math.max(1, phase);
}
function getBossPhaseThresholds() {
  const raw = staticData.balance.boss_phase_thresholds;
  if (Array.isArray(raw)) {
    const list = raw.map((value) => typeof value == "number" ? value : Number(value)).filter((value) => Number.isFinite(value) && value > 0 && value < 1).sort((a, b2) => b2 - a);
    if (list.length > 0) {
      return list;
    }
  }
  return [0.66, 0.33];
}
function getBossFromWorld(worldState, bossId) {
  for (const entry of worldState.bosses) {
    if (entry.boss_id == bossId) {
      return entry;
    }
  }
  return null;
}
function getPlayerPowerScore(state) {
  const hqLevel = clampInt(state.lab.hqLevel ?? 1, 0, 999);
  const hqMult = getBalanceNumber("boss_power_hq_mult", 10);
  const buildingMult = getBalanceNumber("boss_power_building_mult", 2);
  let total = hqLevel * hqMult;
  const buildings = state.lab.buildings || {};
  for (const [id, entry] of Object.entries(buildings)) {
    if (id == "lab_th") {
      continue;
    }
    const level = clampInt(entry?.level ?? 0, 0, 999);
    total += level * buildingMult;
  }
  if (!Number.isFinite(total) || total <= 0) {
    total = 1;
  }
  return Math.floor(total);
}
function computeBossTokens(damage) {
  const divisor = Math.max(1, getBalanceNumber("boss_token_divisor", 1000));
  const tokens = Math.floor(damage / divisor);
  return clampInt(tokens, 0, 1e6);
}
function computeBossRewards(boss, playerId) {
  const entries = Object.entries(boss.contributors).map(([id, value]) => ({ id, value: clampInt(value, 0, Number.MAX_SAFE_INTEGER) })).filter((entry) => entry.value > 0).sort((a, b2) => b2.value - a.value);
  const total = entries.length;
  if (total == 0) {
    return { rewardTier: "none", grants: {} };
  }
  let rankIndex = -1;
  for (let i = 0;i < entries.length; i++) {
    if (entries[i].id == playerId) {
      rankIndex = i;
      break;
    }
  }
  if (rankIndex < 0) {
    return { rewardTier: "none", grants: {} };
  }
  const percentile = (rankIndex + 1) / total;
  let tier = "t4";
  if (percentile <= 0.1) {
    tier = "t1";
  } else if (percentile <= 0.25) {
    tier = "t2";
  } else if (percentile <= 0.5) {
    tier = "t3";
  }
  const base = getBossRewardTable(tier);
  const phaseBonus = getBalanceNumber("boss_reward_phase_bonus", 0.1);
  const phaseMult = Math.max(0, 1 + (boss.phase - 1) * phaseBonus);
  const grants = {};
  for (const [resId, amountRaw] of Object.entries(base)) {
    if (!isValidResourceId(resId)) {
      continue;
    }
    const amount = clampInt(amountRaw, 0, 1e6);
    const finalAmount = Math.floor(amount * phaseMult);
    if (finalAmount > 0) {
      grants[resId] = finalAmount;
    }
  }
  return { rewardTier: tier, grants };
}
function getBossRewardTable(tier) {
  const table = staticData.balance.boss_rewards;
  if (table && typeof table == "object") {
    const entry = table[tier];
    if (entry && typeof entry == "object") {
      return entry;
    }
  }
  if (tier == "t1") {
    return { arcane_shard: 5, time_crystal: 5 };
  }
  if (tier == "t2") {
    return { arcane_shard: 3, time_crystal: 1 };
  }
  if (tier == "t3") {
    return { arcane_shard: 2 };
  }
  return { arcane_shard: 1 };
}
function getZoneRotation(world, zoneId) {
  for (const entry of world.zones) {
    if (entry.zone_id == zoneId) {
      return entry;
    }
  }
  return null;
}
function computeZoneDrops(zone, heat, seedBase) {
  const loot = {};
  const minAmount = clampInt(getBalanceNumber("world_drop_min", 1), 0, 1e6);
  const maxAmount = clampInt(getBalanceNumber("world_drop_max", 3), minAmount, 1e6);
  const amountRoll = seededRandom01(`${seedBase}:amount`);
  const baseAmount = Math.floor(minAmount + (maxAmount - minAmount) * amountRoll);
  const hazardChance = clampChance(getBalanceNumber("world_hazard_base_chance", 0.02) + heat * getBalanceNumber("world_heat_hazard_bonus", 0.003));
  let finalAmount = baseAmount;
  if (seededRandom01(`${seedBase}:hazard`) < hazardChance) {
    finalAmount = Math.floor(finalAmount * getBalanceNumber("world_hazard_loss_mult", 0.6));
  }
  if (finalAmount > 0) {
    const resourceId = pickWeightedResource(zone.drops, `${seedBase}:drop`);
    if (resourceId) {
      loot[resourceId] = (loot[resourceId] ?? 0) + finalAmount;
    }
  }
  const rareChance = clampChance(getBalanceNumber("world_rare_base_chance", 0.05) + heat * getBalanceNumber("world_heat_rare_bonus", 0.002));
  if (seededRandom01(`${seedBase}:rare`) < rareChance) {
    const rareTable = zone.rare_drops && Object.keys(zone.rare_drops).length > 0 ? zone.rare_drops : zone.drops;
    const rareId = pickWeightedResource(rareTable, `${seedBase}:rare_drop`);
    const rareAmount = clampInt(getBalanceNumber("world_rare_amount", 1), 0, 1e6);
    if (rareId && rareAmount > 0) {
      loot[rareId] = (loot[rareId] ?? 0) + rareAmount;
    }
  }
  return loot;
}
function pickWeightedResource(table, seed) {
  const entries = Object.entries(table).filter(([id, weight]) => {
    if (!id || !isValidResourceId(id)) {
      return false;
    }
    return Number.isFinite(weight) && weight > 0;
  });
  if (entries.length == 0) {
    return isValidResourceId("essence") ? "essence" : "";
  }
  let total = 0;
  for (const [, weight] of entries) {
    total += Number(weight);
  }
  if (total <= 0) {
    return entries[0][0];
  }
  const roll = seededRandom01(seed) * total;
  let acc = 0;
  for (const [id, weight] of entries) {
    acc += Number(weight);
    if (roll <= acc) {
      return id;
    }
  }
  return entries[entries.length - 1][0];
}
function makeWorldSessionId(playerId, clientActionId, zoneId) {
  const seed = `${WORLD_SECRET}:${playerId}:${clientActionId}:${zoneId}:world_session`;
  return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}
function makeOrderId(playerId, clientActionId) {
  const seed = `${playerId}:${clientActionId}:order`;
  return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}
function makeTradeJobId(providerId, clientActionId) {
  const seed = `${providerId}:${clientActionId}:trade_job`;
  return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}
function makeTradeRunId(customerId, clientActionId, jobId) {
  const seed = `${customerId}:${clientActionId}:${jobId}:trade_run`;
  return createHash("sha256").update(seed).digest("hex").slice(0, 32);
}
function computeTradeOutput(minValue, maxValue, seed) {
  const min = clampInt(minValue, 0, TRADE_MAX_AMOUNT);
  const max = clampInt(maxValue, 0, TRADE_MAX_AMOUNT);
  if (max <= 0 && min <= 0) {
    return 0;
  }
  const low = Math.min(min, max);
  const high = Math.max(min, max);
  if (high <= 0) {
    return 0;
  }
  const range = high - low + 1;
  const roll = seededRandom01(seed);
  return low + Math.floor(roll * range);
}
function normalizeTradeJobInput(body) {
  const inputResourceId = typeof body?.input_resource_id == "string" ? body.input_resource_id.trim() : "";
  const outputResourceId = typeof body?.output_resource_id == "string" ? body.output_resource_id.trim() : "";
  if (!inputResourceId || !isValidResourceId(inputResourceId)) {
    return { ok: false, error: "Unknown input_resource_id." };
  }
  if (!outputResourceId || !isValidResourceId(outputResourceId)) {
    return { ok: false, error: "Unknown output_resource_id." };
  }
  const inputAmount = clampInt(body?.input_amount ?? 0, 0, TRADE_MAX_AMOUNT);
  if (inputAmount <= 0) {
    return { ok: false, error: "Invalid input_amount." };
  }
  const outputMin = clampInt(body?.output_min ?? 0, 0, TRADE_MAX_AMOUNT);
  const outputMax = clampInt(body?.output_max ?? 0, 0, TRADE_MAX_AMOUNT);
  if (outputMin <= 0 || outputMax <= 0 || outputMin > outputMax) {
    return { ok: false, error: "Invalid output range." };
  }
  const durationSec = clampInt(body?.duration_sec ?? 0, 0, TRADE_MAX_DURATION_SEC);
  let commissionResourceId = typeof body?.commission_resource_id == "string" ? body.commission_resource_id.trim() : "";
  if (!commissionResourceId) {
    commissionResourceId = "essence";
  }
  if (!isValidResourceId(commissionResourceId)) {
    return { ok: false, error: "Unknown commission_resource_id." };
  }
  const commissionAmount = clampInt(body?.commission_amount ?? 0, 0, TRADE_MAX_AMOUNT);
  const queueLimit = clampInt(body?.queue_limit ?? 1, 1, TRADE_MAX_QUEUE);
  return {
    ok: true,
    data: {
      inputResourceId,
      inputAmount,
      outputResourceId,
      outputMin,
      outputMax,
      durationSec,
      commissionResourceId,
      commissionAmount,
      queueLimit
    }
  };
}
function createTradeJob(providerId, clientActionId, body) {
  const normalized = normalizeTradeJobInput(body);
  if (!normalized.ok) {
    return { error: normalized.error };
  }
  const {
    inputResourceId,
    inputAmount,
    outputResourceId,
    outputMin,
    outputMax,
    durationSec,
    commissionResourceId,
    commissionAmount,
    queueLimit
  } = normalized.data;
  const jobId = makeTradeJobId(providerId, clientActionId);
  const now = Date.now();
  let state = null;
  db.transaction(() => {
    state = ensurePlayerState(providerId);
    const existing = getTradeJobStmt.get(jobId);
    if (!existing) {
      insertTradeJobStmt.run(jobId, providerId, inputResourceId, inputAmount, outputResourceId, outputMin, outputMax, durationSec, commissionResourceId, commissionAmount, queueLimit, TRADE_JOB_STATUS_OPEN, now);
    }
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, providerId);
    insertActionStmt.run(providerId, clientActionId, "TRADE_JOB_CREATE", JSON.stringify(body ?? {}), JSON.stringify(state), now);
  })();
  if (!state) {
    return { error: "Failed to resolve provider state." };
  }
  return { state, jobId };
}
function submitTradeRun(customerId, clientActionId, body) {
  const jobId = typeof body?.job_id == "string" ? body.job_id.trim() : "";
  if (!jobId) {
    return { error: "Missing job_id." };
  }
  const stored = getIdempotentState(customerId, clientActionId, "TRADE_SUBMIT", body);
  const runId = makeTradeRunId(customerId, clientActionId, jobId);
  if (stored) {
    const existingRun2 = getTradeRunStmt.get(runId);
    return {
      state: stored,
      runId,
      completesAt: existingRun2 ? Number(existingRun2.completes_at ?? 0) : undefined
    };
  }
  const job = getTradeJobStmt.get(jobId);
  if (!job) {
    return { error: "Trade job not found." };
  }
  const existingRun = getTradeRunStmt.get(runId);
  if (existingRun) {
    const current = ensurePlayerState(customerId);
    return { state: current, runId, completesAt: Number(existingRun.completes_at ?? 0) };
  }
  if (String(job.status).toUpperCase() != TRADE_JOB_STATUS_OPEN) {
    return { error: "Trade job not open." };
  }
  if (job.provider_id == customerId) {
    return { error: "Cannot submit to your own trade job." };
  }
  const pendingRow = countTradeRunsStmt.get(jobId, TRADE_RUN_STATUS_PENDING);
  const pending = pendingRow ? clampInt(pendingRow.count, 0, TRADE_MAX_QUEUE) : 0;
  const queueLimit = clampInt(job.queue_limit, 1, TRADE_MAX_QUEUE);
  if (pending >= queueLimit) {
    return { error: "Trade job queue is full." };
  }
  const inputResourceId = String(job.input_resource_id || "");
  const outputResourceId = String(job.output_resource_id || "");
  const commissionResourceId = String(job.commission_resource_id || "essence");
  if (!isValidResourceId(inputResourceId) || !isValidResourceId(outputResourceId)) {
    return { error: "Invalid trade job resources." };
  }
  if (!isValidResourceId(commissionResourceId)) {
    return { error: "Invalid commission resource." };
  }
  const inputAmount = clampInt(job.input_amount, 0, TRADE_MAX_AMOUNT);
  const commissionAmount = clampInt(job.commission_amount, 0, TRADE_MAX_AMOUNT);
  if (inputAmount <= 0) {
    return { error: "Invalid trade job input amount." };
  }
  const customerState = ensurePlayerState(customerId);
  const required = {};
  required[inputResourceId] = (required[inputResourceId] ?? 0) + inputAmount;
  if (commissionAmount > 0) {
    required[commissionResourceId] = (required[commissionResourceId] ?? 0) + commissionAmount;
  }
  for (const [resId, amount] of Object.entries(required)) {
    if (isSuspiciousAmount(amount)) {
      logSuspiciousAction(customerId, { [resId]: -amount }, "TRADE_SUBMIT", runId);
      return { error: "Suspicious trade submit amount." };
    }
  }
  for (const [resId, amount] of Object.entries(required)) {
    if ((customerState.wallet[resId] ?? 0) < amount) {
      return { error: "Insufficient resources." };
    }
  }
  const now = Date.now();
  const completesAt = now + clampInt(job.duration_sec, 0, TRADE_MAX_DURATION_SEC) * 1000;
  const rngSeed = createHash("sha256").update(`${TRADE_SECRET}:${runId}`).digest("hex");
  db.transaction(() => {
    const beforeWallet = cloneWallet(customerState.wallet);
    for (const [resId, amount] of Object.entries(required)) {
      customerState.wallet[resId] = (customerState.wallet[resId] ?? 0) - amount;
      if (customerState.wallet[resId] < 0) {
        customerState.wallet[resId] = 0;
      }
      addEscrow(customerId, resId, amount);
    }
    assertWalletInvariant(customerState.wallet);
    insertTradeRunStmt.run(runId, jobId, customerId, now, completesAt, inputAmount, TRADE_RUN_STATUS_PENDING, 0, rngSeed);
    customerState.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(customerState), now, customerId);
    insertActionStmt.run(customerId, clientActionId, "TRADE_SUBMIT", JSON.stringify(body ?? {}), JSON.stringify(customerState), now);
    const delta = computeWalletDelta(beforeWallet, customerState.wallet);
    auditWalletMutation(customerId, delta, "TRADE_SUBMIT", runId, now);
  })();
  return { state: customerState, runId, completesAt };
}
function claimTradeRun(customerId, clientActionId, body) {
  const runId = typeof body?.run_id == "string" ? body.run_id.trim() : "";
  if (!runId) {
    return { error: "Missing run_id." };
  }
  const stored = getIdempotentState(customerId, clientActionId, "TRADE_CLAIM", body);
  if (stored) {
    return { state: stored };
  }
  const run = getTradeRunStmt.get(runId);
  if (!run) {
    return { error: "Trade run not found." };
  }
  if (run.customer_id != customerId) {
    return { error: "Trade run does not belong to player." };
  }
  if (String(run.status).toUpperCase() == TRADE_RUN_STATUS_CLAIMED) {
    return { error: "Trade run already claimed." };
  }
  const now = Date.now();
  const completesAt = clampInt(run.completes_at, 0, Number.MAX_SAFE_INTEGER);
  if (completesAt > now) {
    return { error: "Trade run not complete." };
  }
  const job = getTradeJobStmt.get(run.job_id);
  if (!job) {
    return { error: "Trade job missing." };
  }
  const inputResourceId = String(job.input_resource_id || "");
  const outputResourceId = String(job.output_resource_id || "");
  const commissionResourceId = String(job.commission_resource_id || "essence");
  if (!isValidResourceId(inputResourceId) || !isValidResourceId(outputResourceId)) {
    return { error: "Invalid trade job resources." };
  }
  if (!isValidResourceId(commissionResourceId)) {
    return { error: "Invalid commission resource." };
  }
  const inputAmount = clampInt(job.input_amount, 0, TRADE_MAX_AMOUNT);
  const commissionAmount = clampInt(job.commission_amount, 0, TRADE_MAX_AMOUNT);
  const outputMin = clampInt(job.output_min, 0, TRADE_MAX_AMOUNT);
  const outputMax = clampInt(job.output_max, 0, TRADE_MAX_AMOUNT);
  let outputAmount = clampInt(run.output_amount, 0, TRADE_MAX_AMOUNT);
  const seed = run.rng_seed && String(run.rng_seed) != "" ? String(run.rng_seed) : createHash("sha256").update(`${TRADE_SECRET}:${runId}`).digest("hex");
  if (outputAmount <= 0) {
    outputAmount = computeTradeOutput(outputMin, outputMax, seed);
  }
  const customerState = ensurePlayerState(customerId);
  const providerState = ensurePlayerState(job.provider_id);
  const required = {};
  required[inputResourceId] = (required[inputResourceId] ?? 0) + inputAmount;
  if (commissionAmount > 0) {
    required[commissionResourceId] = (required[commissionResourceId] ?? 0) + commissionAmount;
  }
  if (isSuspiciousAmount(outputAmount) || isSuspiciousAmount(commissionAmount)) {
    if (outputAmount > 0) {
      logSuspiciousAction(customerId, { [outputResourceId]: outputAmount }, "TRADE_CLAIM", runId);
    }
    if (commissionAmount > 0) {
      logSuspiciousAction(job.provider_id, { [commissionResourceId]: commissionAmount }, "TRADE_CLAIM", runId);
    }
    return { error: "Suspicious trade claim amount." };
  }
  db.transaction(() => {
    const beforeCustomer = cloneWallet(customerState.wallet);
    const beforeProvider = cloneWallet(providerState.wallet);
    for (const [resId, amount] of Object.entries(required)) {
      if (!subtractEscrow(customerId, resId, amount)) {
        throw new HttpError(400, "Escrow mismatch.");
      }
    }
    updateTradeRunStmt.run(TRADE_RUN_STATUS_CLAIMED, outputAmount, runId);
    if (outputAmount > 0) {
      applyWalletGrant(customerState.wallet, { [outputResourceId]: outputAmount });
    }
    if (commissionAmount > 0) {
      providerState.wallet[commissionResourceId] = clampAmount(providerState.wallet[commissionResourceId] ?? 0) + commissionAmount;
    }
    assertWalletInvariant(customerState.wallet);
    assertWalletInvariant(providerState.wallet);
    customerState.updated_at = now;
    providerState.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(customerState), now, customerId);
    updatePlayerStmt.run(JSON.stringify(providerState), now, job.provider_id);
    insertActionStmt.run(customerId, clientActionId, "TRADE_CLAIM", JSON.stringify(body ?? {}), JSON.stringify(customerState), now);
    const customerDelta = computeWalletDelta(beforeCustomer, customerState.wallet);
    const providerDelta = computeWalletDelta(beforeProvider, providerState.wallet);
    auditWalletMutation(customerId, customerDelta, "TRADE_CLAIM_CUSTOMER", runId, now);
    auditWalletMutation(job.provider_id, providerDelta, "TRADE_CLAIM_PROVIDER", runId, now);
  })();
  return { state: customerState, outputAmount };
}
function enterWorldSession(playerId, clientActionId, body, debugBypass = false) {
  const zoneId = typeof body?.zone_id == "string" ? body.zone_id.trim() : "";
  if (!zoneId) {
    return { error: "Missing zone_id." };
  }
  if (!isValidZoneId(zoneId)) {
    return { error: "Unknown zone_id." };
  }
  const stored = getIdempotentState(playerId, clientActionId, "WORLD_ENTER", body);
  const sessionId = makeWorldSessionId(playerId, clientActionId, zoneId);
  if (stored) {
    return { state: stored, sessionId, zoneId, modifiers: stored.world.sessions[sessionId]?.modifiers ?? [] };
  }
  const now = Date.now();
  const entryFee = getWorldEntryFee();
  if (entryFee > 0 && isSuspiciousAmount(entryFee)) {
    logSuspiciousAction(playerId, { essence: -entryFee }, "WORLD_ENTER", zoneId);
    return { error: "Suspicious entry fee." };
  }
  let state = null;
  let modifiers = [];
  db.transaction(() => {
    state = ensurePlayerState(playerId);
    const beforeWallet = cloneWallet(state.wallet);
    const world = ensurePlayerWorld(state, now);
    const cooldownMs = Math.max(0, Math.floor(getBalanceNumber("world_gate_cooldown_seconds", 3600) * 1000));
    const remainingMs = world.last_gate_entry_at > 0 ? Math.max(0, world.last_gate_entry_at + cooldownMs - now) : 0;
    if (remainingMs > 0)
      throw new HttpError(400, `World Gate cooldown: ${Math.ceil(remainingMs / 1000)} seconds remaining.`);
    const zoneRotation = getZoneRotation(ensureWorldState(now), zoneId);
    if (!zoneRotation)
      throw new HttpError(400, "Zone is not available.");
    modifiers = zoneRotation.modifier_ids.slice();
    refreshWorldPlayer(world, now);
    if (!debugBypass) {
      const gate = ensureBuildingState(state, "world_gate");
      if (gate.level <= 0) {
        throw new HttpError(400, "World Gate locked.");
      }
      const dailyLimit = getWorldDailyEntryLimit();
      if (world.daily_entries >= dailyLimit) {
        throw new HttpError(400, "Daily entry limit reached.");
      }
      if (entryFee > 0) {
        const essence = clampAmount(state.wallet.essence ?? 0);
        if (essence < entryFee) {
          throw new HttpError(400, "Insufficient Essence for entry fee.");
        }
        state.wallet.essence = essence - entryFee;
      }
    }
    if (!world.sessions[sessionId]) {
      world.sessions[sessionId] = {
        session_id: sessionId,
        zone_id: zoneId,
        started_at: now,
        last_farm_at: 0,
        pending_loot: {},
        blocks_farmed: 0,
        modifiers: zoneRotation.modifier_ids.slice()
      };
    }
    world.daily_entries += 1;
    world.last_gate_entry_at = now;
    assertWalletInvariant(state.wallet);
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, playerId);
    insertActionStmt.run(playerId, clientActionId, "WORLD_ENTER", JSON.stringify(body ?? {}), JSON.stringify(state), now);
    const delta = computeWalletDelta(beforeWallet, state.wallet);
    auditWalletMutation(playerId, delta, "WORLD_ENTER", sessionId, now);
  })();
  if (!state) {
    return { error: "Failed to resolve player state." };
  }
  return {
    state,
    sessionId,
    zoneId,
    modifiers
  };
}
function farmWorldSession(playerId, clientActionId, body) {
  const sessionId = typeof body?.session_id == "string" ? body.session_id.trim() : "";
  if (!sessionId) {
    return { error: "Missing session_id." };
  }
  const stored = getIdempotentState(playerId, clientActionId, "WORLD_FARM", body);
  if (stored) {
    const world = stored.world;
    const session = world.sessions[sessionId];
    const zoneId = session ? session.zone_id : "";
    const heat2 = zoneId && world.zone_progress[zoneId] ? world.zone_progress[zoneId].heat : 0;
    return {
      state: stored,
      sessionId,
      drops: {},
      heat: heat2,
      stamina: world.stamina
    };
  }
  let state = null;
  let drops = {};
  let heat = 0;
  let stamina = 0;
  const now = Date.now();
  db.transaction(() => {
    state = ensurePlayerState(playerId);
    const world = ensurePlayerWorld(state, now);
    refreshWorldPlayer(world, now);
    const session = world.sessions[sessionId];
    if (!session) {
      throw new HttpError(400, "Session not found.");
    }
    const zoneId = session.zone_id;
    if (!isValidZoneId(zoneId)) {
      throw new HttpError(400, "Invalid zone.");
    }
    const zoneDef = staticData.zones[zoneId];
    if (!zoneDef) {
      throw new HttpError(400, "Zone data missing.");
    }
    const blocks = clampInt(body?.blocks ?? 1, 1, getWorldMaxBlocksPerAction());
    if (world.stamina < blocks) {
      throw new HttpError(400, "Not enough stamina.");
    }
    const progress = ensureZoneProgress(world, zoneId, now);
    let currentHeat = progress.heat;
    const heatGain = getWorldHeatGain();
    const heatMax = getWorldHeatMax();
    for (let i = 0;i < blocks; i++) {
      const seed = `${WORLD_SECRET}:${playerId}:${clientActionId}:${i}`;
      const blockDrops = computeZoneDrops(zoneDef, currentHeat, seed);
      applyWalletGrant(drops, blockDrops);
      currentHeat = Math.min(heatMax, currentHeat + heatGain);
      progress.reputation = clampInt(progress.reputation + 1, 0, Number.MAX_SAFE_INTEGER);
    }
    progress.heat = currentHeat;
    progress.last_heat_at = now;
    session.last_farm_at = now;
    session.blocks_farmed = clampInt(session.blocks_farmed + blocks, 0, Number.MAX_SAFE_INTEGER);
    applyWalletGrant(session.pending_loot, drops);
    world.stamina = Math.max(0, world.stamina - blocks);
    world.last_stamina_at = now;
    heat = progress.heat;
    stamina = world.stamina;
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, playerId);
    insertActionStmt.run(playerId, clientActionId, "WORLD_FARM", JSON.stringify(body ?? {}), JSON.stringify(state), now);
  })();
  if (!state) {
    return { error: "Failed to resolve player state." };
  }
  return { state, sessionId, drops, heat, stamina };
}
function claimWorldSession(playerId, clientActionId, body) {
  const sessionId = typeof body?.session_id == "string" ? body.session_id.trim() : "";
  if (!sessionId) {
    return { error: "Missing session_id." };
  }
  const stored = getIdempotentState(playerId, clientActionId, "WORLD_CLAIM", body);
  if (stored) {
    return { state: stored, sessionId, claimed: {} };
  }
  const previewState = ensurePlayerState(playerId);
  const previewWorld = ensurePlayerWorld(previewState, Date.now());
  const previewSession = previewWorld.sessions[sessionId];
  if (!previewSession) {
    return { error: "Session not found." };
  }
  const previewClaimed = normalizeLoot(previewSession.pending_loot);
  for (const amount of Object.values(previewClaimed)) {
    if (isSuspiciousAmount(amount)) {
      logSuspiciousAction(playerId, previewClaimed, "WORLD_CLAIM", sessionId);
      return { error: "Suspicious claim amount." };
    }
  }
  let state = null;
  let claimed = {};
  const now = Date.now();
  db.transaction(() => {
    state = ensurePlayerState(playerId);
    const beforeWallet = cloneWallet(state.wallet);
    const world = ensurePlayerWorld(state, now);
    refreshWorldPlayer(world, now);
    const session = world.sessions[sessionId];
    if (!session) {
      throw new HttpError(400, "Session not found.");
    }
    claimed = normalizeLoot(session.pending_loot);
    if (Object.keys(claimed).length > 0) {
      applyWalletGrant(state.wallet, claimed);
    }
    session.pending_loot = {};
    assertWalletInvariant(state.wallet);
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, playerId);
    insertActionStmt.run(playerId, clientActionId, "WORLD_CLAIM", JSON.stringify(body ?? {}), JSON.stringify(state), now);
    const delta = computeWalletDelta(beforeWallet, state.wallet);
    auditWalletMutation(playerId, delta, "WORLD_CLAIM", sessionId, now);
  })();
  if (!state) {
    return { error: "Failed to resolve player state." };
  }
  return { state, sessionId, claimed };
}
function attackBoss(playerId, clientActionId, body, ip) {
  const bossId = typeof body?.boss_id == "string" ? body.boss_id.trim() : "";
  if (!bossId) {
    return { error: "Missing boss_id." };
  }
  if (!isValidBossId(bossId)) {
    return { error: "Unknown boss_id." };
  }
  const now = Date.now();
  const worldState = ensureWorldState(now);
  const bossState = getBossFromWorld(worldState, bossId);
  if (!bossState) {
    return { error: "Boss not available." };
  }
  if (now < bossState.window_starts_at || now > bossState.window_ends_at) {
    return { error: "Boss window closed." };
  }
  const attackFee = getBossAttackFee();
  if (attackFee > 0 && isSuspiciousAmount(attackFee)) {
    logSuspiciousAction(playerId, { essence: -attackFee }, "BOSS_ATTACK", bossId);
    return { error: "Suspicious boss fee." };
  }
  if (!allowBossIp(ip, bossState.window_ends_at)) {
    return { error: "Boss attack rate limit reached." };
  }
  const stored = getIdempotentState(playerId, clientActionId, "BOSS_ATTACK", body);
  if (stored) {
    const existingBoss = getBossFromWorld(ensureWorldState(now), bossId);
    const score = existingBoss?.contributors[playerId] ?? 0;
    return {
      state: stored,
      boss: existingBoss ?? bossState,
      damage: 0,
      contributorScore: score,
      tokens: 0
    };
  }
  let state = null;
  let damage = 0;
  let tokens = 0;
  let contributorScore = 0;
  db.transaction(() => {
    state = ensurePlayerState(playerId);
    const beforeWallet = cloneWallet(state.wallet);
    const world = ensurePlayerWorld(state, now);
    refreshWorldPlayer(world, now);
    if (world.boss_tickets <= 0) {
      throw new HttpError(400, "No boss tickets available.");
    }
    if (attackFee > 0) {
      const essence = clampAmount(state.wallet.essence ?? 0);
      if (essence < attackFee) {
        throw new HttpError(400, "Insufficient Essence for boss fee.");
      }
      state.wallet.essence = essence - attackFee;
    }
    const freshWorldState = ensureWorldState(now);
    const bossEntry = getBossFromWorld(freshWorldState, bossId);
    if (!bossEntry) {
      throw new HttpError(400, "Boss not available.");
    }
    if (now < bossEntry.window_starts_at || now > bossEntry.window_ends_at) {
      throw new HttpError(400, "Boss window closed.");
    }
    const power = getPlayerPowerScore(state);
    const variance = clampChance(getBalanceNumber("boss_damage_variance", 0.15));
    const roll = seededRandom01(`${WORLD_SECRET}:boss:${playerId}:${clientActionId}:${bossId}`);
    const mult = 1 - variance + roll * variance * 2;
    damage = Math.max(1, Math.floor(power * mult));
    const cap = clampInt(getBalanceNumber("boss_damage_cap", 1e5), 1, 1e9);
    damage = Math.min(damage, cap);
    damage = Math.min(damage, bossEntry.hp);
    bossEntry.hp = Math.max(0, bossEntry.hp - damage);
    bossEntry.phase = computeBossPhase(bossEntry.hp, bossEntry.max_hp);
    const existing = clampInt(bossEntry.contributors[playerId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
    contributorScore = existing + damage;
    bossEntry.contributors[playerId] = contributorScore;
    world.boss_tickets = Math.max(0, world.boss_tickets - 1);
    world.last_boss_ticket_at = now;
    tokens = computeBossTokens(damage);
    if (tokens > 0) {
      world.boss_tokens = clampInt(world.boss_tokens + tokens, 0, Number.MAX_SAFE_INTEGER);
    }
    assertWalletInvariant(state.wallet);
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, playerId);
    updateWorldStmt.run(JSON.stringify(freshWorldState), now);
    insertActionStmt.run(playerId, clientActionId, "BOSS_ATTACK", JSON.stringify(body ?? {}), JSON.stringify(state), now);
    const delta = computeWalletDelta(beforeWallet, state.wallet);
    auditWalletMutation(playerId, delta, "BOSS_ATTACK", bossId, now);
  })();
  if (!state) {
    return { error: "Failed to resolve player state." };
  }
  const latestWorld = ensureWorldState(now);
  const latestBoss = getBossFromWorld(latestWorld, bossId) ?? bossState;
  return { state, boss: latestBoss, damage, contributorScore, tokens };
}
function claimBossRewards(playerId, clientActionId, body) {
  const bossId = typeof body?.boss_id == "string" ? body.boss_id.trim() : "";
  if (!bossId) {
    return { error: "Missing boss_id." };
  }
  if (!isValidBossId(bossId)) {
    return { error: "Unknown boss_id." };
  }
  const now = Date.now();
  const worldState = ensureWorldState(now);
  const bossState = getBossFromWorld(worldState, bossId);
  if (!bossState) {
    return { error: "Boss not available." };
  }
  if (now <= bossState.window_ends_at) {
    return { error: "Boss window still active." };
  }
  const stored = getIdempotentState(playerId, clientActionId, "BOSS_CLAIM", body);
  if (stored) {
    return { state: stored, claimed: {} };
  }
  const previewScore = clampInt(bossState.contributors[playerId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
  if (previewScore <= 0) {
    return { error: "No contribution recorded." };
  }
  const previewRewards = computeBossRewards(bossState, playerId);
  for (const amount of Object.values(previewRewards.grants)) {
    if (isSuspiciousAmount(amount)) {
      logSuspiciousAction(playerId, previewRewards.grants, "BOSS_CLAIM", bossId);
      return { error: "Suspicious boss reward amount." };
    }
  }
  let state = null;
  let claimed = {};
  let tier = previewRewards.rewardTier;
  db.transaction(() => {
    state = ensurePlayerState(playerId);
    const beforeWallet = cloneWallet(state.wallet);
    const world = ensurePlayerWorld(state, now);
    refreshWorldPlayer(world, now);
    const lastClaim = clampInt(world.boss_claims[bossId] ?? 0, 0, Number.MAX_SAFE_INTEGER);
    if (lastClaim >= bossState.window_ends_at) {
      throw new HttpError(400, "Rewards already claimed.");
    }
    claimed = previewRewards.grants;
    if (Object.keys(claimed).length > 0) {
      applyWalletGrant(state.wallet, claimed);
    }
    world.boss_claims[bossId] = bossState.window_ends_at;
    assertWalletInvariant(state.wallet);
    state.updated_at = now;
    updatePlayerStmt.run(JSON.stringify(state), now, playerId);
    insertActionStmt.run(playerId, clientActionId, "BOSS_CLAIM", JSON.stringify(body ?? {}), JSON.stringify(state), now);
    const delta = computeWalletDelta(beforeWallet, state.wallet);
    auditWalletMutation(playerId, delta, "BOSS_CLAIM", bossId, now);
  })();
  if (!state) {
    return { error: "Failed to resolve player state." };
  }
  return { state, claimed, tier };
}
function getEscrowAmount(playerId, resourceId) {
  const row = getEscrowStmt.get(playerId, resourceId);
  if (!row) {
    return 0;
  }
  return clampAmount(row.amount);
}
function addEscrow(playerId, resourceId, amount) {
  const delta = clampAmount(amount);
  if (delta <= 0) {
    return;
  }
  addEscrowStmt.run(playerId, resourceId, delta);
}
function subtractEscrow(playerId, resourceId, amount) {
  const delta = clampAmount(amount);
  if (delta <= 0) {
    return true;
  }
  const current = getEscrowAmount(playerId, resourceId);
  if (current < delta) {
    return false;
  }
  setEscrowStmt.run(playerId, resourceId, current - delta);
  return true;
}
function getOrderRemaining(orderId, totalAmount) {
  const filledRow = getOrderFillsSumStmt.get(orderId);
  const filled = filledRow ? clampAmount(filledRow.filled) : 0;
  return Math.max(0, totalAmount - filled);
}
function isValidResourceId(resourceId) {
  if (staticData.resources.size == 0) {
    return true;
  }
  return staticData.resources.has(resourceId);
}
function isValidZoneId(zoneId) {
  if (Object.keys(staticData.zones).length == 0) {
    return true;
  }
  return !!staticData.zones[zoneId];
}
function isValidBossId(bossId) {
  if (Object.keys(staticData.bosses).length == 0) {
    return true;
  }
  return !!staticData.bosses[bossId];
}
function runBackendTests() {
  console.log("Running backend action tests...");
  const idStore = new Set;
  const playerId = "test_player";
  const state = createDefaultState(playerId, "Tester", Date.now());
  state.wallet.essence = 1000;
  state.wallet.core = 20;
  const actionId = "action-1";
  const first = applyWithIdempotency(state, actionId, "UPGRADE_BUILDING", { building_id: "essence_reactor" }, idStore);
  const second = applyWithIdempotency(state, actionId, "UPGRADE_BUILDING", { building_id: "essence_reactor" }, idStore);
  if (first.applied && !second.applied) {
    console.log("PASS: idempotency prevents double apply");
  } else {
    console.error("FAIL: idempotency test");
  }
  const invalid = applyAction(state, "SET_BUILDING_ROUTE", {
    building_id: "essence_reactor",
    route: "invalid_route"
  });
  if (invalid.error) {
    console.log("PASS: invalid route rejected");
  } else {
    console.error("FAIL: invalid route test");
  }
  const expState = createDefaultState("exp_player", "Tester", Date.now());
  expState.lab.hqLevel = 3;
  const hq = ensureBuildingState(expState, "lab_th");
  hq.level = 3;
  hq.route = "Scientific";
  const chamber = ensureBuildingState(expState, "experiment_chamber");
  chamber.level = 1;
  expState.wallet.essence = 500;
  expState.wallet.core = 10;
  const expActionId = "exp-action-1";
  const beforeEssence = expState.wallet.essence;
  const expFirst = applyWithIdempotency(expState, expActionId, "START_EXPERIMENT", { experiment_id: "refine_core" }, idStore);
  const afterEssence = expFirst.state?.wallet.essence ?? expState.wallet.essence;
  const expSecond = applyWithIdempotency(expState, expActionId, "START_EXPERIMENT", { experiment_id: "refine_core" }, idStore);
  if (expFirst.applied && !expSecond.applied && afterEssence < beforeEssence) {
    console.log("PASS: experiment idempotency prevents double spend");
  } else {
    if (expFirst.error) {
      console.error("FAIL: experiment idempotency test - first error:", expFirst.error);
    } else if (expSecond.error) {
      console.error("FAIL: experiment idempotency test - second error:", expSecond.error);
    } else {
      console.error("FAIL: experiment idempotency test", { firstApplied: expFirst.applied, secondApplied: expSecond.applied, beforeEssence, afterEssence });
    }
  }
  const boostState = createDefaultState("boost_player", "Tester", Date.now());
  boostState.lab.hqLevel = 3;
  const boostHq = ensureBuildingState(boostState, "lab_th");
  boostHq.level = 3;
  boostHq.route = "Scientific";
  const boostChamber = ensureBuildingState(boostState, "experiment_chamber");
  boostChamber.level = 1;
  boostState.wallet.essence = 500;
  boostState.wallet.arcane_shard = 5;
  const boostResult = applyAction(boostState, "START_EXPERIMENT", { experiment_id: "volatile_overclock" }, "exp-boost-1");
  if (boostResult.error) {
    console.error("FAIL: boost experiment failed to start");
  } else {
    const runtime = ensureLabRuntime(boostState);
    const expiresAt = runtime.boosts["volatile_overclock"]?.expires_at ?? 0;
    cleanupLabRuntime(runtime, expiresAt + 1);
    if (!runtime.boosts["volatile_overclock"]) {
      console.log("PASS: boost expires after duration");
    } else {
      console.error("FAIL: boost expiry test");
    }
  }
  const researchState = createDefaultState("research_player", "Tester", Date.now());
  researchState.lab.hqLevel = 3;
  const researchHq = ensureBuildingState(researchState, "lab_th");
  researchHq.level = 3;
  researchHq.route = "Scientific";
  const archives = ensureBuildingState(researchState, "arcane_archives");
  archives.level = 1;
  researchState.wallet.essence = 500;
  const startResearch = applyStartResearch(researchState, { research_id: "archive_basics" }, 1000);
  if (startResearch.error) {
    console.error("FAIL: research start failed");
  } else {
    const claimResearch = applyClaimResearch(researchState, { research_id: "archive_basics" }, 1000 + 60 * 1000 + 1);
    if (!claimResearch.error && researchState.research_flags["archive_basics"]) {
      console.log("PASS: research completion unlocks flag");
    } else {
      console.error("FAIL: research completion test");
    }
  }
  const marketSellerId = `market_seller_${crypto.randomUUID()}`;
  const marketBuyerId = `market_buyer_${crypto.randomUUID()}`;
  const marketNow = Date.now();
  const sellerState = createDefaultState(marketSellerId, "Market Seller", marketNow);
  const buyerState = createDefaultState(marketBuyerId, "Market Buyer", marketNow);
  sellerState.wallet.core = 50;
  buyerState.wallet.essence = 1000;
  try {
    insertPlayerStmt.run(marketSellerId, sellerState.display_name ?? "Market Seller", JSON.stringify(sellerState), marketNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(sellerState), marketNow, marketSellerId);
  }
  try {
    insertPlayerStmt.run(marketBuyerId, buyerState.display_name ?? "Market Buyer", JSON.stringify(buyerState), marketNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(buyerState), marketNow, marketBuyerId);
  }
  const feeBps = getMarketFeeBps();
  const orderActionId = "market-order-1";
  const orderId = makeOrderId(marketSellerId, orderActionId);
  const orderAmount = 20;
  const priceAmount = 5;
  db.transaction(() => {
    sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) - orderAmount;
    addEscrow(marketSellerId, "core", orderAmount);
    insertOrderStmt.run(orderId, marketSellerId, MARKET_TYPE_SELL, "core", orderAmount, "essence", priceAmount, feeBps, MARKET_STATUS_OPEN, marketNow);
    sellerState.updated_at = marketNow;
    updatePlayerStmt.run(JSON.stringify(sellerState), marketNow, marketSellerId);
    insertActionStmt.run(marketSellerId, orderActionId, "MARKET_ORDER", JSON.stringify({ resource_id: "core", amount: orderAmount, price_amount: priceAmount }), JSON.stringify(sellerState), marketNow);
  })();
  const escrowAfterOrder = getEscrowAmount(marketSellerId, "core");
  if (escrowAfterOrder == orderAmount) {
    console.log("PASS: market order locks escrow");
  } else {
    console.error("FAIL: market order escrow mismatch");
  }
  const storedOrderState = getIdempotentState(marketSellerId, orderActionId);
  if (storedOrderState) {
    console.log("PASS: market order idempotency detected");
  } else {
    console.error("FAIL: market order idempotency missing");
  }
  const cancelActionId = "market-cancel-1";
  const remaining = getOrderRemaining(orderId, orderAmount);
  db.transaction(() => {
    updateOrderStatusStmt.run(MARKET_STATUS_CANCELED, orderId);
    if (remaining > 0) {
      subtractEscrow(marketSellerId, "core", remaining);
      sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) + remaining;
    }
    sellerState.updated_at = Date.now();
    updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
    insertActionStmt.run(marketSellerId, cancelActionId, "MARKET_CANCEL", JSON.stringify({ order_id: orderId }), JSON.stringify(sellerState), sellerState.updated_at);
  })();
  const escrowAfterCancel = getEscrowAmount(marketSellerId, "core");
  if (escrowAfterCancel == 0) {
    console.log("PASS: market cancel releases escrow");
  } else {
    console.error("FAIL: market cancel escrow not released");
  }
  const order2ActionId = "market-order-2";
  const order2Id = makeOrderId(marketSellerId, order2ActionId);
  const order2Amount = 30;
  db.transaction(() => {
    sellerState.wallet.core = clampAmount(sellerState.wallet.core ?? 0) - order2Amount;
    addEscrow(marketSellerId, "core", order2Amount);
    insertOrderStmt.run(order2Id, marketSellerId, MARKET_TYPE_SELL, "core", order2Amount, "essence", priceAmount, feeBps, MARKET_STATUS_OPEN, Date.now());
    sellerState.updated_at = Date.now();
    updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
    insertActionStmt.run(marketSellerId, order2ActionId, "MARKET_ORDER", JSON.stringify({ resource_id: "core", amount: order2Amount, price_amount: priceAmount }), JSON.stringify(sellerState), sellerState.updated_at);
  })();
  const buyActionId = "market-buy-1";
  const buyAmount = 10;
  const totalPrice = buyAmount * priceAmount;
  const fee = Math.floor(totalPrice * feeBps / 1e4);
  const buyerEssenceBefore = clampAmount(buyerState.wallet.essence ?? 0);
  const buyerCoreBefore = clampAmount(buyerState.wallet.core ?? 0);
  const sellerEssenceBefore = clampAmount(sellerState.wallet.essence ?? 0);
  const escrowBeforeBuy = getEscrowAmount(marketSellerId, "core");
  db.transaction(() => {
    buyerState.wallet.essence = clampAmount(buyerState.wallet.essence ?? 0) - totalPrice;
    applyWalletGrant(buyerState.wallet, { core: buyAmount });
    sellerState.wallet.essence = clampAmount(sellerState.wallet.essence ?? 0) + Math.max(0, totalPrice - fee);
    subtractEscrow(marketSellerId, "core", buyAmount);
    insertFillStmt.run(crypto.randomUUID(), order2Id, marketBuyerId, buyAmount, totalPrice, fee, Date.now());
    buyerState.updated_at = Date.now();
    sellerState.updated_at = buyerState.updated_at;
    updatePlayerStmt.run(JSON.stringify(buyerState), buyerState.updated_at, marketBuyerId);
    updatePlayerStmt.run(JSON.stringify(sellerState), sellerState.updated_at, marketSellerId);
    insertActionStmt.run(marketBuyerId, buyActionId, "MARKET_BUY", JSON.stringify({ order_id: order2Id, amount: buyAmount }), JSON.stringify(buyerState), buyerState.updated_at);
  })();
  const remainingAfterBuy = getOrderRemaining(order2Id, order2Amount);
  if (remainingAfterBuy == order2Amount - buyAmount) {
    console.log("PASS: market partial fill reduces remaining");
  } else {
    console.error("FAIL: market remaining mismatch after buy");
  }
  const escrowAfterBuy = getEscrowAmount(marketSellerId, "core");
  if (buyerState.wallet.essence == buyerEssenceBefore - totalPrice && buyerState.wallet.core == buyerCoreBefore + buyAmount) {
    console.log("PASS: market buy transfers buyer resources");
  } else {
    console.error("FAIL: market buyer wallet mismatch");
  }
  if (sellerState.wallet.essence == sellerEssenceBefore + Math.max(0, totalPrice - fee)) {
    console.log("PASS: market buy transfers seller resources");
  } else {
    console.error("FAIL: market seller wallet mismatch");
  }
  if (escrowAfterBuy == escrowBeforeBuy - buyAmount) {
    console.log("PASS: market buy releases escrow");
  } else {
    console.error("FAIL: market escrow mismatch after buy");
  }
  const storedBuyState = getIdempotentState(marketBuyerId, buyActionId);
  if (storedBuyState) {
    console.log("PASS: market buy idempotency detected");
  } else {
    console.error("FAIL: market buy idempotency missing");
  }
  const invariantBuyer = getWalletInvariantError(buyerState.wallet);
  const invariantSeller = getWalletInvariantError(sellerState.wallet);
  if (!invariantBuyer && !invariantSeller) {
    console.log("PASS: wallet invariants hold after market buy");
  } else {
    console.error("FAIL: wallet invariants violated after market buy");
  }
  const auditBefore = countAuditStmt.get(marketBuyerId)?.count ?? 0;
  try {
    rejectSuspiciousMarketBuy(marketBuyerId, "order_suspicious", "core", "essence", getSuspiciousAmountThreshold() + 1, 1);
    console.error("FAIL: huge buy was not rejected");
  } catch {
    const auditAfter = countAuditStmt.get(marketBuyerId)?.count ?? 0;
    if (auditAfter > auditBefore) {
      console.log("PASS: huge buy rejected and logged");
    } else {
      console.error("FAIL: huge buy not logged");
    }
  }
  const tradeProviderId = `trade_provider_${crypto.randomUUID()}`;
  const tradeCustomerId = `trade_customer_${crypto.randomUUID()}`;
  const tradeNow = Date.now();
  const tradeProviderState = createDefaultState(tradeProviderId, "Trade Provider", tradeNow);
  const tradeCustomerState = createDefaultState(tradeCustomerId, "Trade Customer", tradeNow);
  tradeCustomerState.wallet.core = 50;
  tradeCustomerState.wallet.essence = 200;
  try {
    insertPlayerStmt.run(tradeProviderId, tradeProviderState.display_name ?? "Trade Provider", JSON.stringify(tradeProviderState), tradeNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(tradeProviderState), tradeNow, tradeProviderId);
  }
  try {
    insertPlayerStmt.run(tradeCustomerId, tradeCustomerState.display_name ?? "Trade Customer", JSON.stringify(tradeCustomerState), tradeNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(tradeCustomerState), tradeNow, tradeCustomerId);
  }
  const tradeJobActionId = "trade-job-1";
  const tradeJobBody = {
    input_resource_id: "core",
    input_amount: 10,
    output_resource_id: "arcane_shard",
    output_min: 1,
    output_max: 3,
    duration_sec: 0,
    commission_resource_id: "essence",
    commission_amount: 20,
    queue_limit: 2
  };
  const tradeJobResult = createTradeJob(tradeProviderId, tradeJobActionId, tradeJobBody);
  if (!tradeJobResult.jobId || !tradeJobResult.state) {
    console.error("FAIL: trade job creation failed");
  } else {
    console.log("PASS: trade job created");
  }
  const tradeJobId = tradeJobResult.jobId ?? makeTradeJobId(tradeProviderId, tradeJobActionId);
  const tradeSubmitActionId = "trade-submit-1";
  const tradeSubmitResult = submitTradeRun(tradeCustomerId, tradeSubmitActionId, {
    job_id: tradeJobId
  });
  if (!tradeSubmitResult.runId || !tradeSubmitResult.state) {
    console.error("FAIL: trade submit failed");
  } else {
    const escrowCore = getEscrowAmount(tradeCustomerId, "core");
    const escrowEssence = getEscrowAmount(tradeCustomerId, "essence");
    if (escrowCore == 10 && escrowEssence == 20) {
      console.log("PASS: trade submit locks escrow");
    } else {
      console.error("FAIL: trade escrow lock mismatch");
    }
  }
  const tradeRunId = tradeSubmitResult.runId ?? makeTradeRunId(tradeCustomerId, tradeSubmitActionId, tradeJobId);
  const customerBeforeClaim = ensurePlayerState(tradeCustomerId);
  const providerBeforeClaim = ensurePlayerState(tradeProviderId);
  const tradeClaimActionId = "trade-claim-1";
  const tradeClaimResult = claimTradeRun(tradeCustomerId, tradeClaimActionId, {
    run_id: tradeRunId
  });
  if (!tradeClaimResult.state) {
    console.error("FAIL: trade claim failed");
  } else {
    const customerAfterClaim = tradeClaimResult.state;
    const providerAfterClaim = ensurePlayerState(tradeProviderId);
    const outputAmount = tradeClaimResult.outputAmount ?? 0;
    const escrowCoreAfter = getEscrowAmount(tradeCustomerId, "core");
    const escrowEssenceAfter = getEscrowAmount(tradeCustomerId, "essence");
    if (escrowCoreAfter == 0 && escrowEssenceAfter == 0) {
      console.log("PASS: trade claim releases escrow");
    } else {
      console.error("FAIL: trade claim escrow not released");
    }
    if ((customerAfterClaim.wallet.arcane_shard ?? 0) >= (customerBeforeClaim.wallet.arcane_shard ?? 0) + outputAmount) {
      console.log("PASS: trade claim awards output");
    } else {
      console.error("FAIL: trade claim output mismatch");
    }
    if ((providerAfterClaim.wallet.essence ?? 0) >= (providerBeforeClaim.wallet.essence ?? 0) + 20) {
      console.log("PASS: trade claim pays commission");
    } else {
      console.error("FAIL: trade commission not paid");
    }
  }
  const tradeClaimRepeat = claimTradeRun(tradeCustomerId, tradeClaimActionId, {
    run_id: tradeRunId
  });
  if (tradeClaimRepeat.state) {
    console.log("PASS: trade claim idempotency detected");
  } else {
    console.error("FAIL: trade claim idempotency missing");
  }
  const worldPlayerId = `world_player_${crypto.randomUUID()}`;
  const worldNow = Date.now();
  const worldPlayerState = createDefaultState(worldPlayerId, "World Tester", worldNow);
  worldPlayerState.research_flags["unlock_world_zones"] = true;
  worldPlayerState.wallet.essence = 100;
  try {
    insertPlayerStmt.run(worldPlayerId, worldPlayerState.display_name ?? "World Tester", JSON.stringify(worldPlayerState), worldNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(worldPlayerState), worldNow, worldPlayerId);
  }
  const zoneIds = Object.keys(staticData.zones);
  const testZoneId = zoneIds.length > 0 ? zoneIds[0] : "zone_corrupted";
  const enterActionId = "world-enter-1";
  const enterResult = enterWorldSession(worldPlayerId, enterActionId, { zone_id: testZoneId });
  if (!enterResult.state || !enterResult.sessionId) {
    console.error("FAIL: world enter failed");
  } else {
    console.log("PASS: world enter created session");
  }
  const sessionId = enterResult.sessionId ?? makeWorldSessionId(worldPlayerId, enterActionId, testZoneId);
  const farmActionId = "world-farm-1";
  const farmResult = farmWorldSession(worldPlayerId, farmActionId, { session_id: sessionId });
  if (!farmResult.state) {
    console.error("FAIL: world farm failed");
  } else {
    const progress = farmResult.state.world.zone_progress[testZoneId];
    if (progress && progress.heat > 0) {
      console.log("PASS: world heat increases on farm");
    } else {
      console.error("FAIL: world heat did not increase");
    }
    const pending = farmResult.state.world.sessions[sessionId]?.pending_loot ?? {};
    const pendingTotal = Object.values(pending).reduce((sum, value) => sum + clampAmount(value), 0);
    if (pendingTotal > 0) {
      console.log("PASS: world farm produced loot");
    } else {
      console.error("FAIL: world farm loot missing");
    }
  }
  const farmRepeat = farmWorldSession(worldPlayerId, farmActionId, { session_id: sessionId });
  if (farmRepeat.state) {
    console.log("PASS: world farm idempotency detected");
  } else {
    console.error("FAIL: world farm idempotency missing");
  }
  const beforeClaimState = ensurePlayerState(worldPlayerId);
  const claimActionId = "world-claim-1";
  const claimResult = claimWorldSession(worldPlayerId, claimActionId, { session_id: sessionId });
  if (!claimResult.state) {
    console.error("FAIL: world claim failed");
  } else {
    const afterClaimState = claimResult.state;
    const beforeEssence2 = clampAmount(beforeClaimState.wallet.essence ?? 0);
    const afterEssence2 = clampAmount(afterClaimState.wallet.essence ?? 0);
    if (afterEssence2 >= beforeEssence2) {
      console.log("PASS: world claim increased wallet");
    } else {
      console.error("FAIL: world claim did not increase wallet");
    }
  }
  const claimRepeat = claimWorldSession(worldPlayerId, claimActionId, { session_id: sessionId });
  if (claimRepeat.state) {
    console.log("PASS: world claim idempotency detected");
  } else {
    console.error("FAIL: world claim idempotency missing");
  }
  const bossPlayerId = `boss_player_${crypto.randomUUID()}`;
  const bossNow = Date.now();
  const bossPlayerState = createDefaultState(bossPlayerId, "Boss Tester", bossNow);
  bossPlayerState.research_flags["archive_basics"] = true;
  bossPlayerState.wallet.essence = 100;
  bossPlayerState.wallet.essence = 100;
  try {
    insertPlayerStmt.run(bossPlayerId, bossPlayerState.display_name ?? "Boss Tester", JSON.stringify(bossPlayerState), bossNow);
  } catch {
    updatePlayerStmt.run(JSON.stringify(bossPlayerState), bossNow, bossPlayerId);
  }
  const bossIds = Object.keys(staticData.bosses);
  const testBossId = bossIds.length > 0 ? bossIds[0] : "boss_common";
  const originalWindow = staticData.balance.boss_window_minutes;
  const originalInterval = staticData.balance.boss_interval_minutes;
  staticData.balance.boss_window_minutes = 120;
  staticData.balance.boss_interval_minutes = 120;
  const attackActionId = "boss-attack-1";
  const beforeAttack = ensurePlayerState(bossPlayerId);
  const beforeTickets = beforeAttack.world.boss_tickets;
  const attackResult = attackBoss(bossPlayerId, attackActionId, { boss_id: testBossId }, "127.0.0.1");
  if (attackResult.error || !attackResult.state) {
    console.error("FAIL: boss attack failed", attackResult.error);
  } else {
    const afterAttack = ensurePlayerState(bossPlayerId);
    if (afterAttack.world.boss_tickets == beforeTickets - 1) {
      console.log("PASS: boss attack consumes ticket");
    } else {
      console.error("FAIL: boss ticket not consumed");
    }
    const attackRepeat = attackBoss(bossPlayerId, attackActionId, { boss_id: testBossId }, "127.0.0.1");
    const worldState = ensureWorldState(Date.now());
    const bossState = getBossFromWorld(worldState, testBossId);
    if (attackRepeat.state && bossState && bossState.contributors[bossPlayerId] == attackResult.contributorScore) {
      console.log("PASS: boss attack idempotency detected");
    } else {
      console.error("FAIL: boss attack idempotency missing");
    }
  }
  staticData.balance.boss_window_minutes = 1;
  staticData.balance.boss_interval_minutes = 120;
  const window2 = getBossWindowTimes(testBossId, Date.now());
  if (Date.now() > window2.end) {
    const closedAttack = attackBoss(bossPlayerId, "boss-attack-closed", { boss_id: testBossId }, "127.0.0.1");
    if (closedAttack.error) {
      console.log("PASS: boss attack rejected outside window");
    } else {
      console.error("FAIL: boss attack should be rejected outside window");
    }
  } else {
    console.log("SKIP: boss outside-window test (window currently open)");
  }
  staticData.balance.boss_window_minutes = originalWindow;
  staticData.balance.boss_interval_minutes = originalInterval;
}
function applyWithIdempotency(state, clientActionId, actionType, payload, store) {
  const key = `${state.player_id}:${clientActionId}`;
  if (store.has(key)) {
    return { applied: false };
  }
  const result = applyAction(state, actionType, payload, clientActionId);
  if (result.error) {
    return { applied: false, error: result.error };
  }
  store.add(key);
  return { applied: true, state: result.state };
}
if (Bun.env.RUN_BACKEND_TESTS == "1") {
  runBackendTests();
  process.exit(0);
} else {
  startServer();
}
