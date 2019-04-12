//*** DESCRIPTION

/

Script to monitor and log all IPC calls to a process
All output is sent to a logging tickerplant setup on port 5010 
Handle open calls are logged to table 'connLog'
Sync & async executiuon calls are logged to table 'queryLog'

If any handles are set before this script is loaded then they will be wrapped and their
logic still executed upong the handle being called

\

//*** COMMAND LINE PARAMS

//.log.params:.Q.def[`logTP`level`logfile!(`::5010;4;hsym `$first system"pwd")].Q.opt .z.x;

//*** REQUIRED SCRIPTS

//*** HANDLES

//*** GLOBAL VARS

// Define the default values of the handles to be set at the end of the script
.log.funcs:()!();;
.log.funcs[`.z.po]:{.log.hand.po[;x]};
.log.funcs[`.z.pc]:{.log.hand.pc[;x]};
.log.funcs[`.z.wo]:{.log.hand.wo[;x]};
.log.funcs[`.z.wc]:{.log.hand.wc[;x]};
.log.funcs[`.z.pw]:{res:.log.hand.pw[;x;y][1];res};
if[@[value;`.z.ac;0b];
    .log.funcs[`.z.ac]:{.log.hand.ac[;x]}
    ];
.log.funcs[`.z.pg]:{res:.log.hand.pg[;x][2];res};
.log.funcs[`.z.ps]:{.log.hand.ps[;x];};
.log.funcs[`.z.ws]:{.log.hand.ws[;x];};
.log.funcs[`.z.ph]:{res:.log.hand.ph[;x][2];res};
.log.funcs[`.z.pp]:{res:.log.hand.pp[;x][2];res};

//.log.funcs:params[`level]#.log.funcs;

// Initialize the dictionary mappings to be called by the default handles
.log.hand.po:()!();
.log.hand.pc:()!();
.log.hand.wo:()!();
.log.hand.wc:()!();
.log.hand.pw:()!();
.log.hand.ac:()!();
.log.hand.pg:()!();
.log.hand.ps:()!();
.log.hand.ws:()!();
.log.hand.ph:()!();
.log.hand.pp:()!();

// Define a counter to track the ID of remote query calls
.log.ID:-1j;
.log.PORT:system"p";
.log.TPPORT:`::5010;
.log.LOGDIR:hsym `$first system"pwd";
.log.LOGFILE:.Q.dd[.log.LOGDIR;`$"_" sv string (first ` vs .z.f;.z.i;.log.PORT)];

// *** FUNCTIONS
.log.openConn:{[port;timeout]
    $[.z.K>3.3;
        neg hopen(`$":unix://",2_string port;timeout);
        neg hopen(port;timeout)
        ]
    }

.log.initHandle:{[timeout]
    set[`.log.hLOG;.[.log.openConn;(.log.TPPORT;timeout);0i]];
    if[.log.hLOG>=0i;
        .[.log.LOGFILE;();:;()];
        set[`.log.hLOG;hopen[.log.LOGFILE]enlist@]
        ];
    }

// Define the deafault behaviour of port open
// A message will be sent to the log TP of the client details
.log.hand.po[0]:{[h]
    msg:(`open;.z.T;h;.z.a;.z.u);
    .log.sendMsg[`connLog;msg];
    }

// Define the default behavior of port close
// A message will be sent to the log TP of the client details
.log.hand.pc[0]:{[h]
    if[h~abs @[first value@;.log.hLOG;.log.hLOG];
        .log.initHandle[1000]
        ];
    }
.log.hand.pc[1]:{[h]
    msg:(`close;.z.T;h;.z.a;.z.u);
    .log.sendMsg[`connLog;msg];
    }

// Define the deafault behaviour of port open
// A message will be sent to the log TP of the client details
.log.hand.wo[0]:{[h]
    msg:(`websocketopen;.z.T;h;.z.a;.z.u);
    .log.sendMsg[`connLog;msg];
    }   

// Define the default behavior of port close
// A message will be sent to the log TP of the client details
.log.hand.wc[0]:{[h]
    msg:(`websocketclose;.z.T;h;.z.a;.z.u);
    .log.sendMsg[`connLog;msg];
    } 

// Define the default behavior of cookie authentication
// This is only set if .z.ac is already defined on the port as otherwise it would overwrite .z.pw
// A message will be sent to the log TP of the client details
.log.hand.ac[0]:{[h]
    msg:(`cookieAuth;.z.T;h;.z.a;.z.u);
    .log.sendMsg[`connLog;msg];
    }

// Define the default behaviour for the password authentication
.log.hand.pw[0]:{[x;y]
    msg:(`passwordAuth;.z.T;0Ni;.z.a;x);
    .log.sendMsg[`connLog;msg];
    }
// Default value is to allow all users
.log.hand.pw[1]:{[x;y]:1b};
.log.hand.pw[2]:{[x;y]
    
    }
// Define the default behaviour of the synchronous message execution handle
// First the global ID which tracks the number of remote requests is increased
.log.hand.pg[0]:{.[`.log.ID;();+;1j]}
// Secondly the inital query is logged to ensure that even if the query fails the request is still logged
.log.hand.pg[1]:{[query]
    msg:(.log.ID;.z.N;`initsync;.z.a;.z.u;.Q.s query;0b);
    .log.sendMsg[`queryLog;msg];
    }
// Thirdly the query is evaluated as normal, this is overwritten if .z.pg logic exists already on the port
.log.hand.pg[2]:value;
// Lastly the success of the query is evaluated and logged to the TP
.log.hand.pg[3]:{[query]
    msg:(.log.ID;.z.N;`endsync;.z.a;.z.u;.Q.s query;1b);
    .log.sendMsg[`queryLog;msg];
    }

// Define the default behaviour of the async message execution handle
// First the global ID which tracks the number of remote requests is increased
.log.hand.ps[0]:{.[`.log.ID;();+;1j]}
// Secondly the query is logged before evaluation to ensure that even if it breaks the log is still kept
.log.hand.ps[1]:{[query]
    msg:(.log.ID;.z.N;`initasync;.z.a;.z.u;.Q.s query;0b);
    .log.sendMsg[`queryLog;msg];
    }
// Thirdly the request is evaluated, this is overwritten if there is already .z.ps logic defined on the port
.log.hand.ps[2]:value;
// Lastly the success of the query is evaluated and logged to the TP
.log.hand.ps[3]:{[query]
    msg:(.log.ID;.z.N;`endasync;.z.a;.z.u;.Q.s query;1b);
    .log.sendMsg[`queryLog;msg];
    }

// Define the default behaviour of the websocket request handler
// First the global ID which tracks the number of remote requests is increased
.log.hand.ws[0]:{.[`.log.ID;();+;1j]}
// Secondly the query is logged to ensure that even if it breaks the log is still kept
.log.hand.ws[1]:{[query]
    msg:(.log.ID;.z.N;`initwebsocket;.z.a;.z.u;.Q.s query;0b);
    .log.sendMsg[`queryLog;msg];
    }
// Thirdly, the request is evaluated, this is overwritten if .z.ws is defined on the port already
.log.hand.ws[2]:{neg[.z.w]x}
// Lastly the success of the query is logged
.log.hand.ws[3]:{[query]
    msg:(.log.ID;0Nt;.z.N;`endwebsocket;.z.a;.z.u;.Q.s query;1b);
    .log.sendMsg[`queryLog;msg];
    }

// Define the default behaviour of the HTTP GET handler
// First the global ID which tracks the number of remote requests is increased
.log.hand.ph[0]:{.[`.log.ID;();+;1j]}
// Secondly the query is logged to ensure that even if it fails the query is still logged
.log.hand.ph[1]:{[query]
    msg:(.log.ID;.z.N;`inithttpget;.z.a;.z.u;.Q.s first query;0b);
    .log.sendMsg[`queryLog;msg];
    }
// .z.ph is always defined by default. Therefore set this as empty and it will be overwritten automatically later
// If .z.ph has been deliberately unset then this will remain blank, consistent with it being unset
.log.hand.ph[2]:@[value;`.z.ph;{[x]0N;}];
// Lastly, log the success of the query
.log.hand.ph[3]:{[query]
    msg:(.log.ID;.z.N;`endhttpget;.z.a;.z.u;.Q.s first query;1b);
    .log.sendMsg[`queryLog;msg];
    }

// Define the default behaviour of the HTTP GET handler
// First the global ID which tracks the number of remote requests is increased
.log.hand.pp[0]:{.[`.log.ID;();+;1j]}
// Secondly the query is logged to ensure that even if it fails the query is still logged
.log.hand.pp[1]:{[query]
    msg:(.log.ID;.z.N;`inithttppost;.z.a;.z.u;.Q.s query;0b);
    .log.sendMsg[`queryLog;msg];
    }
// HTTP POST is defined by the evaluation of the first argument, this wil be overwritten if .z.pp is already defined
.log.hand.pp[2]:{value first x};
// Lastly log the success of the query
.log.hand.pp[3]:{[query]
    msg:(.log.ID;.z.N;`endhttppost;.z.a;.z.u;.Q.s query;1b);
    .log.sendMsg[`queryLog;msg];
    }

// Helper function to return the log function name for each handler
// e.g. .log.hand.pg is returned for input `.z.pg
.log.default:{
    ` sv (`.log.hand;last ` vs x)
    }

// Helper function to assist on wrapping the existint handlers if they exist
.log.addHand:{[h;orig;default]
    pos:$[h in `.z.pc`.z.pg`.z.ps`.z.ws`.z.ph`.z.pp;2;1];
    .[default;pos;:;orig]
    }

// Function to send messages to the logTP
.log.sendMsg:{[t;msg]
    .log.hLOG(`.u.upd;t;.log.PORT,msg);
    }

// Function to check if pre-existing handler definitions are set and wrap them if so
// Once the logic is correct then set the .z.?? handler function to its new value
.log.wrapFunc:{
    default:.log.default[x];
    if[(not x~`.z.ph) & count orig:@[value;x;()];
        .log.addHand[x;orig;default];
        ];
    .[x;();:;.log.funcs[x]];
    }

// Function to initialise all the handles required to be set on the port
// As defined by .log.funcs above
.log.init:{
    .log.wrapFunc@/:key .log.funcs;
    .log.initHandle[30000];
    }

//*** RUNNER
//.log.init[]
