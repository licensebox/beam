#include <erl_nif.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdatomic.h>
typedef struct lb_client lb_client;
typedef struct {void*context;void(*on_sign_in)(void*,const char*,const char*);double(*clock)(void*);int(*machine_binding)(void*,char*,size_t);int(*cancelled)(void*);} lb_callbacks;
extern int lb_client_create_json(const char*,const lb_callbacks*,lb_client**);
extern int lb_client_call_json(lb_client*,const char*,const char*,char**);
extern void lb_client_destroy(lb_client*);extern void lb_free(void*);
extern const char*lb_result_code(int);extern const char*lb_error_code(lb_client*);extern const char*lb_error_message(lb_client*);
extern int lb_derive_binding(const char*,const char*,const char*,char*,size_t);
extern int lb_native_binding(const char*,char*,size_t);
extern int lb_verify_lease_json(const char*,const char*,const char*,double,char**);
typedef struct {lb_client*c;ErlNifMutex*operation,*mutex;ErlNifCond*condition;ErlNifPid owner;ErlNifMonitor monitor;ErlNifEnv*reply_env;ERL_NIF_TERM reply;unsigned long seq;int hooks,waiting;atomic_int dead,failed;} Host;
static ErlNifResourceType*type;
static ERL_NIF_TERM atom(ErlNifEnv*e,const char*s){return enif_make_atom(e,s);}
static ERL_NIF_TERM binary(ErlNifEnv*e,const char*s){ERL_NIF_TERM t;unsigned char*p=enif_make_new_binary(e,strlen(s),&t);memcpy(p,s,strlen(s));return t;}
static ERL_NIF_TERM error(ErlNifEnv*e,const char*code,const char*message){return enif_make_tuple2(e,atom(e,"error"),enif_make_tuple2(e,binary(e,code),binary(e,message)));}
static ERL_NIF_TERM result_error(ErlNifEnv*e,int r,lb_client*c){const char*code=lb_result_code(r),*detail=code;if(c&&strcmp(code,"invalid_argument")){const char*saved=lb_error_code(c);if(strcmp(saved,"ok"))code=saved;detail=lb_error_message(c);}return error(e,code,detail);}
static char*string(ErlNifEnv*e,ERL_NIF_TERM t){ErlNifBinary b;if(!enif_inspect_binary(e,t,&b)||memchr(b.data,0,b.size))return NULL;char*s=enif_alloc(b.size+1);if(!s)return NULL;memcpy(s,b.data,b.size);s[b.size]=0;return s;}
static int hook(Host*h,const char*kind,const char*u,const char*c){
 enif_mutex_lock(h->mutex);if(h->dead||h->failed){h->failed=1;enif_mutex_unlock(h->mutex);return 0;}
 ErlNifEnv*e=enif_alloc_env();h->waiting=1;h->seq++;enif_clear_env(h->reply_env);
 ERL_NIF_TERM args=u?enif_make_list2(e,binary(e,u),binary(e,c)):enif_make_list(e,0);
 ERL_NIF_TERM msg=enif_make_tuple5(e,atom(e,"licensebox_callback"),enif_make_resource(e,h),enif_make_ulong(e,h->seq),atom(e,kind),args);
 int sent=enif_send(NULL,&h->owner,e,msg);enif_free_env(e);
 if(!sent){h->dead=1;h->waiting=0;}
 while(h->waiting&&!h->dead)enif_cond_wait(h->condition,h->mutex);
 int arity;const ERL_NIF_TERM*parts;int ok=!h->dead&&enif_get_tuple(h->reply_env,h->reply,&arity,&parts)&&arity==2&&enif_is_identical(parts[0],atom(h->reply_env,"ok"));
 if(ok)h->reply=parts[1];else h->failed=1;
 enif_mutex_unlock(h->mutex);return ok;
}
static void sign_cb(void*p,const char*u,const char*c){hook(p,"on_sign_in",u,c);}
static double clock_cb(void*p){Host*h=p;if(!hook(h,"clock",NULL,NULL))return 0;double v;ErlNifSInt64 i;if(enif_get_double(h->reply_env,h->reply,&v)&&isfinite(v))return v;if(enif_get_int64(h->reply_env,h->reply,&i))return (double)i;h->failed=1;return 0;}
static int binding_cb(void*p,char*out,size_t cap){Host*h=p;if(!hook(h,"machine_binding",NULL,NULL))return 1;ErlNifBinary b;if(!enif_inspect_binary(h->reply_env,h->reply,&b)||b.size>=cap||memchr(b.data,0,b.size)){h->failed=1;return 1;}memcpy(out,b.data,b.size);out[b.size]=0;return 0;}
static int cancel_cb(void*p){Host*h=p;if(h->failed||h->dead)return 1;if(!(h->hooks&8))return 0;if(!hook(h,"cancelled",NULL,NULL))return 1;if(enif_is_identical(h->reply,atom(h->reply_env,"true")))return 1;if(enif_is_identical(h->reply,atom(h->reply_env,"false")))return 0;h->failed=1;return 1;}
static void owner_down(ErlNifEnv*e,void*p,ErlNifPid*pid,ErlNifMonitor*monitor){(void)e;(void)pid;(void)monitor;Host*h=p;enif_mutex_lock(h->mutex);h->dead=1;enif_cond_broadcast(h->condition);enif_mutex_unlock(h->mutex);}
static void destructor(ErlNifEnv*e,void*p){(void)e;Host*h=p;if(h->c)lb_client_destroy(h->c);if(h->reply_env)enif_free_env(h->reply_env);if(h->operation)enif_mutex_destroy(h->operation);if(h->mutex)enif_mutex_destroy(h->mutex);if(h->condition)enif_cond_destroy(h->condition);}
static ERL_NIF_TERM create(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;int mask;char*opts=string(e,a[0]);if(!opts||!enif_get_int(e,a[1],&mask)){enif_free(opts);return enif_make_badarg(e);}Host*h=enif_alloc_resource(type,sizeof(*h));memset(h,0,sizeof(*h));atomic_init(&h->dead,0);atomic_init(&h->failed,0);h->hooks=mask;h->operation=enif_mutex_create("licensebox_operation");h->mutex=enif_mutex_create("licensebox_callback");h->condition=enif_cond_create("licensebox_callback");h->reply_env=enif_alloc_env();enif_self(e,&h->owner);enif_monitor_process(e,h,&h->owner,&h->monitor);lb_callbacks cb={h,mask&1?sign_cb:NULL,mask&2?clock_cb:NULL,mask&4?binding_cb:NULL,cancel_cb};int r=lb_client_create_json(opts,&cb,&h->c);enif_free(opts);ERL_NIF_TERM answer=r?result_error(e,r,NULL):enif_make_tuple2(e,atom(e,"ok"),enif_make_resource(e,h));enif_release_resource(h);return answer;}
static ERL_NIF_TERM call(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;Host*h;if(!enif_get_resource(e,a[0],type,(void**)&h))return enif_make_badarg(e);char*op=string(e,a[1]),*args=string(e,a[2]);if(!op||!args){enif_free(op);enif_free(args);return enif_make_badarg(e);}if(enif_mutex_trylock(h->operation)!=0){enif_free(op);enif_free(args);return error(e,"invalid_argument","client busy");}char*out=NULL;int r=h->c?lb_client_call_json(h->c,op,args,&out):22;enif_free(op);enif_free(args);ERL_NIF_TERM answer;if(h->failed||h->dead){h->failed=0;answer=error(e,"callback_error","application callback failed");}else if(r)answer=result_error(e,r,h->c);else if(!out)answer=error(e,"protocol_error","missing native JSON");else answer=enif_make_tuple2(e,atom(e,"ok"),binary(e,out));lb_free(out);enif_mutex_unlock(h->operation);return answer;}
static ERL_NIF_TERM reply(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;Host*h;unsigned long seq;if(!enif_get_resource(e,a[0],type,(void**)&h)||!enif_get_ulong(e,a[1],&seq))return enif_make_badarg(e);enif_mutex_lock(h->mutex);if(h->waiting&&seq==h->seq){h->reply=enif_make_copy(h->reply_env,a[2]);h->waiting=0;enif_cond_signal(h->condition);}enif_mutex_unlock(h->mutex);return atom(e,"ok");}
static ERL_NIF_TERM close_client(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;Host*h;if(!enif_get_resource(e,a[0],type,(void**)&h))return enif_make_badarg(e);if(enif_mutex_trylock(h->operation)!=0)return error(e,"invalid_argument","client busy");if(h->c){lb_client_destroy(h->c);h->c=NULL;}enif_mutex_unlock(h->operation);return atom(e,"ok");}
static ERL_NIF_TERM derive(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;char*p=string(e,a[0]),*s=string(e,a[1]),*raw=string(e,a[2]);if(!p||!s||!raw){enif_free(p);enif_free(s);enif_free(raw);return error(e,"identity_unavailable","invalid identity");}char out[128];int r=lb_derive_binding(p,s,raw,out,sizeof(out));enif_free(p);enif_free(s);enif_free(raw);return r?result_error(e,r,NULL):enif_make_tuple2(e,atom(e,"ok"),binary(e,out));}
static ERL_NIF_TERM native(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;char*p=string(e,a[0]);if(!p)return enif_make_badarg(e);char out[128];int r=lb_native_binding(p,out,sizeof(out));enif_free(p);return r?result_error(e,r,NULL):enif_make_tuple2(e,atom(e,"ok"),binary(e,out));}
static ERL_NIF_TERM verify(ErlNifEnv*e,int n,const ERL_NIF_TERM a[]){(void)n;char*t=string(e,a[0]),*p=string(e,a[1]),*keys=string(e,a[2]);double now;ErlNifSInt64 i;if(!enif_get_double(e,a[3],&now)){if(!enif_get_int64(e,a[3],&i))now=NAN;else now=(double)i;}char*out=NULL;int r=t&&p&&keys&&isfinite(now)?lb_verify_lease_json(t,p,keys,now,&out):22;enif_free(t);enif_free(p);enif_free(keys);ERL_NIF_TERM answer=r?result_error(e,r,NULL):enif_make_tuple2(e,atom(e,"ok"),binary(e,out));lb_free(out);return answer;}
static int load(ErlNifEnv*e,void**p,ERL_NIF_TERM info){(void)p;(void)info;ErlNifResourceTypeInit init={.dtor=destructor,.down=owner_down};type=enif_open_resource_type_x(e,"licensebox_client",&init,ERL_NIF_RT_CREATE,NULL);return type?0:1;}
static ErlNifFunc funcs[]={{"create",2,create,ERL_NIF_DIRTY_JOB_IO_BOUND},{"call",3,call,ERL_NIF_DIRTY_JOB_IO_BOUND},{"reply",3,reply,0},{"close",1,close_client,ERL_NIF_DIRTY_JOB_IO_BOUND},{"derive",3,derive,ERL_NIF_DIRTY_JOB_IO_BOUND},{"native",1,native,ERL_NIF_DIRTY_JOB_IO_BOUND},{"verify",4,verify,ERL_NIF_DIRTY_JOB_IO_BOUND}};
ERL_NIF_INIT(licensebox_native,funcs,load,NULL,NULL,NULL)
