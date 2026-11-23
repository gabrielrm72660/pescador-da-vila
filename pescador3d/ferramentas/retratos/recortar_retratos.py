import cv2, numpy as np, sys
KERN=int(sys.argv[1]); DIL=int(sys.argv[2]); SUF=sys.argv[3]
im = cv2.imread('original.png')
H,W = im.shape[:2]
lab = cv2.cvtColor(im, cv2.COLOR_BGR2LAB).astype(np.float32)
bg = np.median(lab[0:60,:,:].reshape(-1,3),axis=0)
d = np.linalg.norm(lab-bg,axis=2)
# fundo = região conectada às bordas com d pequeno (buracos internos viram figura)
th = 13
cand = (d<=th).astype(np.uint8)
# remove rabiscos finos de ruído: abre/fecha
cand = cv2.morphologyEx(cand, cv2.MORPH_OPEN, np.ones((3,3),np.uint8))
# núcleo do fundo: só regiões largas (abertura grande) ligadas à borda; recupera a borda fina por reconstrução curta
core = cv2.morphologyEx(cand, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(KERN,KERN)))
n, lbl = cv2.connectedComponents(core, connectivity=4)
border = set(np.unique(np.concatenate([lbl[0,:],lbl[-1,:],lbl[:,0],lbl[:,-1]])))
border.discard(0)
bgcore = np.isin(lbl, list(border)).astype(np.uint8)
bgmask = bgcore.copy()
k = np.ones((3,3),np.uint8)
for _ in range(DIL):
    bgmask = cv2.dilate(bgmask,k) & cand
bgmask = bgmask>0
fg = (~bgmask).astype(np.uint8)
# tira ilhotas pequenas (fumaça etc. ficam se grandes)
n, lb, st, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
keep = np.zeros_like(fg)
for i in range(1,n):
    if st[i,cv2.CC_STAT_AREA] > 3000: keep[lb==i]=1
fg = keep
cv2.imwrite('fg.png', fg*255)

# recortes: linhas de corte entre vizinhos (x_topo, x_base) interpoladas em y
cortes = [ (300,303), (670,633), (992,992), (1278,1272) ]   # entre Zefa|Jacinto, Jacinto|Toinho, Toinho|Rosa, Rosa|Abílio
ys = np.arange(H)
def xcut(c, y):
    t = np.clip((y-420)/110.0, 0, 1)
    return c[0]*(1-t)+c[1]*t
xs = np.arange(W)[None,:]
regioes=[]
lim = [np.full(H,-1.0)] + [xcut(c,ys) for c in cortes] + [np.full(H,1e9)]
nomes = ['zefa','jacinto','toinho','rosa','abilio']
for i,nome in enumerate(nomes):
    reg = (xs>=lim[i][:,None]) & (xs<lim[i+1][:,None])
    m = (fg>0)&reg
    # maior componente
    m8 = m.astype(np.uint8)
    n, lb, st, _ = cv2.connectedComponentsWithStats(m8, connectivity=8)
    big = 1+np.argmax(st[1:,cv2.CC_STAT_AREA])
    m8 = (lb==big).astype(np.uint8)
    # corpo: tira "orelhas" estreitas (restos do vão entre figuras) abrindo só a parte de baixo
    if nome != 'jacinto':
        baixo = m8.copy(); baixo[:470] = 0
        baixo = cv2.morphologyEx(baixo, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(25,25)))
        m8[470:] = baixo[470:]
    n2, lb2, st2, _ = cv2.connectedComponentsWithStats(m8, connectivity=8)
    m8 = (lb2==(1+np.argmax(st2[1:,cv2.CC_STAT_AREA]))).astype(np.uint8)
    # corpo: preenche cada linha entre o menor e o maior x (busto sem vãos internos)
    for y in range(470, H):
        xx = np.where(m8[y]>0)[0]
        if len(xx)>0:
            m8[y, xx.min():xx.max()+1] = 1
    # alfa suave: erode 1px e desfoca bordas
    er = cv2.erode(m8, np.ones((3,3),np.uint8), iterations=1)
    a = cv2.GaussianBlur(er.astype(np.float32)*255,(0,0),1.2)
    ys_, xs_ = np.where(m8>0)
    x0,x1,y0,y1 = xs_.min(),xs_.max()+1,ys_.min(),ys_.max()+1
    pad=6
    x0=max(0,x0-pad);y0=max(0,y0-pad);x1=min(W,x1+pad);y1=min(H,y1+pad)
    rgb = im[y0:y1,x0:x1].copy()
    alpha = a[y0:y1,x0:x1]
    # desvanece a base (pincelada do pé) nos últimos 7% da altura
    h = y1-y0
    fade = np.ones(h,np.float32)
    f0 = int(h*0.93)
    fade[f0:] = np.linspace(1,0,h-f0)
    alpha = alpha*fade[:,None]
    out = np.dstack([rgb, alpha.astype(np.uint8)])
    cv2.imwrite(f'{nome}.png', out)
    print(nome, (x0,y0,x1,y1), out.shape)
# folha de conferência sobre fundo escuro
imgs=[cv2.imread(f'{n}.png',cv2.IMREAD_UNCHANGED) for n in nomes]
hmax=max(i.shape[0] for i in imgs)
folha=np.full((hmax+20, sum(i.shape[1] for i in imgs)+20*(len(imgs)+1),3),(40,30,22),np.uint8)
x=20
for i in imgs:
    a=i[:,:,3:4].astype(np.float32)/255
    reg=folha[10+hmax-i.shape[0]:10+hmax, x:x+i.shape[1]].astype(np.float32)
    folha[10+hmax-i.shape[0]:10+hmax, x:x+i.shape[1]] = (i[:,:,:3]*a+reg*(1-a)).astype(np.uint8)
    x+=i.shape[1]+20
cv2.imwrite('folha_escura_'+SUF+'.png', folha)
