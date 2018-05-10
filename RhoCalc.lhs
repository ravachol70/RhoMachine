\begin{code}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, FunctionalDependencies, AllowAmbiguousTypes #-}

module RhoCalc(
  Nominal
  ,Name
  ,Behavioral
  ,Process
  ,RhoProcess
  ,procToIntegerList
  ,integerListToProc
  ,discriminator
  ,popen
  ,pclose
  ,nopen
  ,nclose
  ,unquote
  ,getNextEntity
  ,getLastEntity
  ,getSubject
  ,getObject
  ,getParLeft
  ,getParRight
  ,getContinuation
  ,getTransmission
  ,getNameCenter
  )
  where
-- import Debug.Trace
-- tracey :: Show a => [Char] -> a -> a
-- tracey name x = trace (name ++ ": " ++ show x) x

class Nominal n where
  code :: p -> n p

data Name p = Address Integer | Code p deriving (Eq,Show)

instance Nominal Name where
  code = Code

class (Nominal n) => Behavioral n p | n -> p where
  zero :: p
  input :: (Nominal n, Eq (n p)) => (n p) -> (n p) -> p -> p
  output :: (Nominal n, Eq (n p)) => (n p) -> p -> p
  par :: p -> p -> p
  eval :: (Nominal n, Eq (n p)) => (n p) -> p

data Process x = Stop 
  | Input x x (Process x)
  | Output x (Process x) 
  | Par (Process x) (Process x)
  | Eval x deriving (Eq,Show)

data RhoProcess = Reflect (Process (Name RhoProcess)) deriving (Eq,Show)

instance Behavioral Name RhoProcess where
  zero = Reflect Stop
  input x y (Reflect p) = Reflect (Input x y p)
  output x (Reflect q) = Reflect (Output x q)
  par (Reflect p) (Reflect q) = Reflect  (Par p q)
  eval x = Reflect (Eval x)

procToIntegerList :: RhoProcess -> [Integer]
discriminator :: RhoProcess -> [Integer]
popen :: [Integer]
pclose :: [Integer]
nopen :: [Integer]
nclose :: [Integer]

discriminator (Reflect Stop)          = [0,0,0,0]
discriminator (Reflect (Input _ _ _)) = [0,0,0,1]
discriminator (Reflect (Output _ _))  = [0,0,1,0]
discriminator (Reflect (Par _ _))     = [0,0,1,1]
discriminator (Reflect (Eval _))      = [0,1,0,0]

popen                                 = [0,1,0,1]
pclose                                = [0,1,1,0]
nopen                                 = [0,1,1,1]
nclose                                = [1,0,0,0]


-- Known issues: in order to provide name equality as bit compare we ...
-- must produce bit vectors for addresses
-- must provide a canonical order for pars
-- must use DeBruijn indices for bound variables
--   [| for( y <- x )P |](l,w,h) = let z = [| (l,w,h) |] in for( z <- x )([| P |](l+1,w,h){z/y})
--   [| for( y1 <- x1 )P1 | ... | for( yN <- xN )PN |](l,w,h) 
--   = let z1 = [| (l,w,h) |] in ... let zN = [| w + N-1 |] in
--     for( z1 <- x )([| P |](l+1,w,h){z1/y}) | ... | for( z <- x )([| P |](l+1,w + N-1,h){zN/y})
-- h is used for descent into names

substitute :: RhoProcess -> Name RhoProcess -> Name RhoProcess -> RhoProcess
substitute (Reflect Stop) y x = (Reflect Stop)
substitute (Reflect (Input a b q)) y x = (Reflect (Input a' b' q'))
  where a' = (if (a == x) then y else a)
        b' = (if (b == x) then (Code (Reflect (Par (Eval b) q))) else b)
        (Reflect q') = (substitute q'' y x)
        q'' = (if (b == x) then (substitute (Reflect q) b' b) else (Reflect q))
substitute (Reflect (Output a q)) y x = (Reflect (Output a' q'))
  where a' = (if (a == x) then y else a)
        (Reflect q') = (substitute (Reflect q) y x)
substitute (Reflect (Par p q)) y x = (Reflect (Par p' q'))
  where (Reflect p') = (substitute (Reflect p) y x)
        (Reflect q') = (substitute (Reflect q) y x)
substitute (Reflect (Eval a)) y x = (Reflect (Eval a'))
  where a' = (if (a == x) then y else a)

-- todo
toBits :: Integer -> [Integer]
toNumber :: [Integer] -> Integer
toBits n = []
toNumber l = 0

deBruijnify :: RhoProcess -> Integer -> Integer -> Integer -> RhoProcess
deBruijnify (Reflect Stop) l w h = (Reflect Stop)
deBruijnify (Reflect (Input (Code px) y q)) l w h = (Reflect (Input x dbny q''))
  where (Reflect q'')    = (substitute q' dbny y)
        q'     = (deBruijnify (Reflect q) (l+1) w h)
        x      = (Code (deBruijnify px l w (h+1)))
        dbny   = (Address dbnidx)
        dbnidx = (toNumber ((toBits l) ++ (toBits w) ++ (toBits h)))
deBruijnify (Reflect (Output (Code px) q)) l w h = (Reflect (Output x q'))
  where x               = (Code (deBruijnify px l w (h+1)))
        (Reflect q')    = (deBruijnify (Reflect q) l w h)
deBruijnify (Reflect (Par p q)) l w h = (Reflect (Par p' q'))
  where (Reflect p')    = (deBruijnify (Reflect p) l w h)
        (Reflect q')    = (deBruijnify (Reflect q) l (w+1) h)
deBruijnify (Reflect (Eval (Code px))) l w h = (Reflect (Eval x))
  where x     = (Code (deBruijnify px l w (h+1)))
deBruijnify (Reflect (Eval (Address addr))) l w h = (Reflect (Eval (Address addr)))

procToIntegerList (Reflect Stop) = tag
  where tag = (discriminator (Reflect Stop))
procToIntegerList (Reflect (Input (Code px) (Code py) q)) = tag ++ nx ++ ny ++ qx
  where tag = (discriminator (Reflect (Input (Code px) (Code py) q)))
        nx  = nopen ++ (procToIntegerList px) ++ nclose
        ny  = nopen ++ (procToIntegerList py) ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Input (Address a) (Code py) q)) = tag ++ nx ++ ny ++ qx
  where tag = (discriminator (Reflect (Input (Address a) (Code py) q)))
        nx  = nopen ++ [a] ++ nclose
        ny  = nopen ++ (procToIntegerList py) ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Input (Code px) (Address a) q)) = tag ++ nx ++ ny ++ qx
  where tag = (discriminator (Reflect (Input (Code px) (Address a) q)))
        nx  = nopen ++ (procToIntegerList px) ++ nclose
        ny  = nopen ++ [a] ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Input (Address ax) (Address ay) q)) = tag ++ nx ++ ny ++ qx
  where tag = (discriminator (Reflect (Input (Address ax) (Address ay) q)))
        nx  = nopen ++ [ax] ++ nclose
        ny  = nopen ++ [ay] ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Output (Code px) q)) = tag ++ nx ++ qx
  where tag = (discriminator (Reflect (Output (Code px) q)))
        nx  = nopen ++ (procToIntegerList px) ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Output (Address a) q)) = tag ++ nx ++ qx
  where tag = (discriminator (Reflect (Output (Address a) q)))
        nx  = nopen ++ [a] ++ nclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Par p q)) = tag ++ px ++ qx
  where tag = (discriminator (Reflect (Par p q)))
        px  = popen ++ (procToIntegerList (Reflect p)) ++ pclose
        qx  = popen ++ (procToIntegerList (Reflect q)) ++ pclose
procToIntegerList (Reflect (Eval (Code px))) = tag ++ nx
  where tag = (discriminator (Reflect (Eval (Code px))))
        nx  = nopen ++ (procToIntegerList px) ++ nclose

--        bit string   open paren   close paren   contents & remainder of the string
unquote :: [Integer] -> [Integer] -> [Integer] -> Maybe ([Integer], [Integer])
unquote (a:b:c:d:l) (oa:ob:oc:od:[]) (ca:cb:cc:cd:[]) =
  if ([a,b,c,d] == [oa,ob,oc,od])
  then
    (h l [oa,ob,oc,od] [ca,cb,cc,cd] 1 [])
  else Nothing
  where h [] _ _ n acc                                        =
          (if (n > 0) then Nothing else Just (acc,[]))
        h (a:b:c:d:l) (oa:ob:oc:od:[]) (ca:cb:cc:cd:[]) 0 acc = Just (acc,(a:b:c:d:l))
        h (a:b:c:d:l) (oa:ob:oc:od:[]) (ca:cb:cc:cd:[]) n acc =
          (if ([a,b,c,d] == [oa,ob,oc,od])
            then
              (h l [oa,ob,oc,od] [ca,cb,cc,cd] (n + 1) (acc ++ [a,b,c,d]))
            else if ([a,b,c,d] == [ca,cb,cc,cd])
                 then (h l [oa,ob,oc,od] [ca,cb,cc,cd] (n - 1) (if (n == 1) then acc else (acc ++ [a,b,c,d])))
                 else (h l [oa,ob,oc,od] [ca,cb,cc,cd] n (acc ++ [a,b,c,d])))

integerListToProc :: [Integer] -> Maybe RhoProcess
getSubject :: [Integer] -> Maybe (RhoProcess,[Integer])
getObject :: [Integer] -> Maybe (RhoProcess,[Integer])
getContinuation :: [Integer] -> Maybe RhoProcess
getTransmission :: [Integer] -> Maybe RhoProcess
getParLeft :: [Integer] -> Maybe (RhoProcess,[Integer])
getParRight :: [Integer] -> Maybe RhoProcess
getNameCenter :: [Integer] -> Maybe RhoProcess

-- todo: replace with do-blocks

getNextEntity l open close =
  case (unquote l open close) of
   Just (contents, remainder) -> (case (integerListToProc contents) of
     Just p -> Just (p, remainder)
     Nothing -> Nothing)
   Nothing -> Nothing

getLastEntity l open close =
  case (unquote l open close) of
   Just (contents, []) -> (integerListToProc contents)
   _ -> Nothing

getNextName l = getNextEntity l nopen nclose

getSubject l = getNextName l  
   
getObject l = getNextName l

getParLeft l = getNextEntity l popen pclose

getContinuation l = getLastEntity l popen pclose

getTransmission l = getLastEntity l popen pclose

getParRight l = getLastEntity l popen pclose

getNameCenter l = getLastEntity l nopen nclose

integerListToProc [] = Just (Reflect Stop)
integerListToProc (0:0:0:0:[]) = Just (Reflect Stop)
integerListToProc (0:0:0:1:l) = 
  case (getSubject l) of
    Just (px,l') -> (case (getObject l') of
      Just (py,l'') -> (case (getContinuation l'') of        
        Just (Reflect q) -> Just (Reflect (Input (Code px) (Code py) q))
        Nothing -> Nothing)
      Nothing -> Nothing)
    Nothing -> Nothing      
integerListToProc (0:0:1:0:l) =
  case (getSubject l) of 
    Just (px,l') -> (case (getTransmission l') of
      Just (Reflect q) -> Just (Reflect (Output (Code px) q))
      Nothing -> Nothing)
    Nothing -> Nothing
integerListToProc (0:0:1:1:l) =
  case (getParLeft l) of 
    Just (pl,l') -> (case (getParRight l') of 
      Just pr -> (case (pl,pr) of
        ((Reflect ql),(Reflect qr)) -> Just (Reflect (Par ql qr)))
      Nothing -> Nothing)
    Nothing -> Nothing
integerListToProc (0:1:0:0:l) = 
  case (getNameCenter l) of
    Just q -> Just (Reflect (Eval (Code q)))
    Nothing -> Nothing

roundtrip :: RhoProcess -> Bool
roundtrip p = case (integerListToProc (procToIntegerList p)) of
  Just q -> p == q
  Nothing -> False
\end{code}
