#version 430

layout(location=0)uniform sampler2D surface_texture;
layout(location=1)uniform sampler3D noise_volume;
layout(location=2)uniform vec3[10] uniform_array;
#if defined(USE_LD)
layout(location=19)uniform mat3 m;
layout(location=22)uniform vec4[3] scales;
layout(location=25)uniform vec3 aspect;
#else
mat3 m=mat3(.42f,-.7f,.58f,.53f,.71f,.46f,-.74f,.12f,.67f);
#endif
out vec4 o;

vec4 march_params = vec4(0.3, 0.0, 0.7, 0.009);
vec3 L=normalize(vec3(2.,.5,-1.));
float l = uniform_array[9].y;
bool w = 1.0 < abs(uniform_array[7].z);

float f(vec3 p)
{
  float a,b,c,r;
  vec3 h,i,j,k;
  if(w)
  {
    // Using mandelbox distance estimator from 2010-09-10 post by Rrrola in fractalforums, because it's better
    // than the one Warma made.
    h=p*.02;
    vec4 r=vec4(h,1); // distance estimate: r.w
#if defined(USE_LD)
    for(int i=0;i<int(scales[2].x);i++)
#else
      for(int i=0;i<9;i++)
#endif
      {
        r.xyz=clamp(r.xyz,-1.,1.)*2.-r.xyz; // laatikko foldaus
        c=dot(r.xyz,r.xyz);
#if defined(USE_LD)
        r*=clamp(max(scales[2].y/c,scales[2].y),.0,1.);
        r=r*vec4(vec3(scales[2].z),abs(scales[2].z))/scales[2].y+vec4(h,1.);
#else
        r*=clamp(max(.824/c,.824),.0,1.);
        r=r*vec4(vec3(-2.742),2.742)+vec4(h,1.);
#endif
      }
    r.xyz*=clamp(h.y+1,.1,1.);
#if defined(USE_LD)
    c=((length(r.xyz)-abs(scales[2].z-1.))/r.w-pow(abs(scales[2].z),float(1)-scales[2].x))*50.;
#else
    c=((length(r.xyz)-3.259)/r.w-.001475)*50.; //-pow(2.259,-8.)
#endif
  }
  else
  {
#if defined(USE_LD)
    h=m*p*scales[0].x;
    i=m*h*scales[0].y;
    j=m*i*scales[0].z;
    k=m*j*scales[0].w;
    a = texture(surface_texture, h.xz).x * scales[1].x;
    b = texture(surface_texture, i.xz).x * scales[1].y;
    c = texture(surface_texture, j.xz).x * scales[1].z;
    r = texture(surface_texture, k.xz).x * scales[1].w;
#else
    h=m*p*.007;
    i=m*h*2.61;
    j=m*i*2.11;
    k=m*j*2.11;
    a = texture(surface_texture, h.xz).x * 2.61;
    b = texture(surface_texture, i.xz).x * 1.77;
    c = texture(surface_texture, j.xz).x * 0.11;
    r = texture(surface_texture, k.xz).x * 0.11;
#endif
    a=r+c+pow(a,2.)+pow(b,2.);
    c=length(p.xz)*.3;
    c=a*(smoothstep(.0,.5,c*.0025)+.5)+p.y-6.*((sin(clamp(pow(c/10.,1.8)-3.14/2.,-1.57,1.57))-1.)*2.+5.)*cos(clamp(.04*c,.0,3.14));
  }
  h = p - uniform_array[8].xyz;
  a=length(h);
  if(a<l)return c+l-a;
  return c;
}

float T(vec3 p, vec3 d, float I, out vec3 P, out vec3 N)
{
  vec3 n,r;
  float a=f(p),c,e,i=1.;
  for(;i>.0;i-=I)
  {
    n = p + d * max(a * march_params.z, 0.02);
    c=f(n);
    if(.0>c)
    {
      for(int j=0;j<5;++j)
      {
        r=(p+n)*.5;
        e=f(r);
        if(.0>e)
        {
          n=r;
          c=e;
        }
        else
        {
          p=r;
          a=e;
        }
      }
      N = normalize(vec3(f(n.xyz + march_params.xyy).x, f(n.xyz + march_params.yxy).x, f(n.xyz + march_params.yyx).x) - c.x);
      break;
    }
    p=n;
    a=c;
  }
  P=p;
  return i;
}

float C(inout vec3 p,vec3 d,vec3 c,float r)
{
  vec3 q=p-c;
  float e=dot(q,q)-r*r,a=dot(q,d);
  if(0>e||0>a)
  {
    e=a*a-e;
    if(0<e)
    {
      p+=max(-a-sqrt(e),.0)*d;
      return length(a*d-q);
    }
  }
  return .0;
}

vec3 Q(vec3 p)
{
  vec3 a,b,c,h,i,j;
  h=m*p;
  i=m*h*3.;
  j=m*i*3.;
  a = (texture(noise_volume, h).xyz - 0.5) * 2.0 * 0.6;
  b = (texture(noise_volume, i).xyz - 0.5) * 2.0 * 0.3;
  c = (texture(noise_volume, j).xyz - 0.5) * 2.0 * 0.1;
  return normalize(a+b+c);
}

void main()
{
#if defined(USE_LD)
  vec2 c=gl_FragCoord.xy*aspect.z-aspect.xy;
#elif defined(SCREEN_H) && defined(SCREEN_W) && (SCREEN_H == 1200) && (SCREEN_W == 1920)
  vec2 c=gl_FragCoord.xy/600.-vec2(1.6,1.);
#elif defined(SCREEN_H) && defined(SCREEN_W) && (SCREEN_H == 1080) && (SCREEN_W == 1920)
  vec2 c=gl_FragCoord.xy/540.-vec2(1.78,1.);
#elif defined(SCREEN_H) && defined(SCREEN_W) && (SCREEN_H == 800) && (SCREEN_W == 1280)
  vec2 c=gl_FragCoord.xy/400.-vec2(1.6,1.);
#else // Assuming 720p.
  vec2 c=gl_FragCoord.xy/360.-vec2(1.78,1.);
#endif
  vec3 p = mix(mix(uniform_array[0], uniform_array[1], uniform_array[7].y), mix(uniform_array[1], uniform_array[2], uniform_array[7].y), uniform_array[7].y) * 3.0;
  vec3 d = normalize(mix(uniform_array[3], uniform_array[4], uniform_array[7].y));
  vec3 q = mix(uniform_array[5], uniform_array[6], uniform_array[7].y);
  vec3 r = normalize(cross(d,q)),N,P;
  q=normalize(cross(r,d));
  d=normalize(d+c.x*r+c.y*q);
  q=vec3(0);
  float e;
  float n;

  r=vec3(109.,14.,86.);
  if(0 < int(uniform_array[7].z) % 2 && 0.0 < C(p, d, r, 9.0))
  {
    d=normalize(d+reflect(-d,normalize(p-r))*.2);
    l=-.2;
    w=!w;
  }

  // World chosen affects iteration parameters.
  if(w)
  {
    march_params = vec4(0.05, 0.0, 0.98, 0.022);
  }

  n = T(p, d, march_params.w, P, N);
  if(.0<n)
  {
    if(w)q=max(dot(L,N),.0)*mix(vec3(.3,.6,.9),vec3(1),smoothstep(-24.,9.,P.y))+pow(max(dot(d,reflect(L,N)),.0),7.)*.11;
    else
    {
      e =T(P + L * 0.5, L, march_params.w * 3.0, q, q);
      q=(1.-e)*(max(dot(L,N),.0)*mix(vec3(.8,.6,.4),vec3(1),smoothstep(-24.,9.,P.y))+pow(max(dot(d,reflect(L,N)),.0),7.)*.11);
    }
    r = P - uniform_array[8];
    e=l+.5-length(r);
    if(0<e)q+=vec3((dot(Q(P*.009),normalize(r))*.1)+.1,-.05,-.05)*smoothstep(.0,.5,e);
  }
  vec3 s=mix(vec3(.9,.8,.8),vec3(.8,.8,.9),d.y*111.*.02)*(dot(Q(p*.006+d*.1),d)*smoothstep(-.2,.5,-d.y)*.2+.8);
  if(w)n=smoothstep(.0,.4,n);
  o = vec4(mix(mix(s, vec3(1), pow(max(dot(d, L), 0.0), 7.0)), q, n), 1.0) - (int(gl_FragCoord.y * 0.5) % 2 + 0.1) * (max(max(smoothstep(0.98, 1.0, uniform_array[7].y), smoothstep(-0.02 * uniform_array[9].x, 0.0, -uniform_array[7].y) * uniform_array[9].x), 0.1) + l * 0.02) * dot(c, c);
  r=p;
  e = C(r, d, uniform_array[8], l + 0.2);
  if(0.0 < e)
  {
    o.xyz -= clamp(1.0 - (dot(r - p, r - p) - dot(P - p, P - p)) * 0.003, 0.0, 1.0) * (1.0 - pow(e / l, 5)) * (dot(Q((r - uniform_array[8]) * 0.009), d) * 0.1 + 0.9);
  }
}