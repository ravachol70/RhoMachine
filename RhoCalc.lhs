
\begin{code}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances, FunctionalDependencies, AllowAmbiguousTypes #-}

module RhoCalc(
  Nominal
  ,Name
  ,Behavioral
  ,Process
  ,RhoProcess
  ,procToIntegerList
  ,discriminator
  )
  where

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

integerListToProc :: [Integer] -> Maybe RhoProcess
getSubject :: [Integer] -> Maybe (RhoProcess,[Integer])
getObject :: [Integer] -> Maybe (RhoProcess,[Integer])
getContinuation :: [Integer] -> Maybe RhoProcess
getTransmission :: [Integer] -> Maybe RhoProcess
getParLeft :: [Integer] -> Maybe (RhoProcess,[Integer])
getParRight :: [Integer] -> Maybe RhoProcess
-- getNameCenter :: [Integer] -> Maybe RhoProcess

discriminator (Reflect Stop)          = [0,0,0,0]
discriminator (Reflect (Input _ _ _)) = [0,0,0,1]
discriminator (Reflect (Output _ _))  = [0,0,1,0]
discriminator (Reflect (Par _ _))     = [0,0,1,1]
discriminator (Reflect (Eval _))      = [0,1,0,0]

popen                                 = [0,1,0,1]
pclose                                = [0,1,1,0]
nopen                                 = [0,1,1,1]
nclose                                = [1,0,0,0]

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
  where h [] _ _ n acc                                  =
          (if (n > 0) then Nothing else Just (acc,[]))
        h (a:b:c:d:l) (oa:ob:oc:od:[]) (ca:cb:cc:cd:[]) 0 acc = Just (acc,(a:b:c:d:l))
        h (a:b:c:d:l) (oa:ob:oc:od:[]) (ca:cb:cc:cd:[]) n acc =
          (if ([a,b,c,d] == [oa,ob,oc,od])
            then
              (h l [oa,ob,oc,od] [ca,cb,cc,cd] (n + 1) (acc ++ [a,b,c,d]))
            else if ([a,b,c,d] == [oa,ob,oc,od])
                 then (h l [oa,ob,oc,od] [ca,cb,cc,cd] (n - 1) (if (n == 1) then acc else (acc ++ [a,b,c,d])))
                 else (h l [oa,ob,oc,od] [ca,cb,cc,cd] n (acc ++ [a,b,c,d])))

getSubject l = 
 case (unquote l nopen nclose) of
   Just (contents, remainder) -> (case (integerListToProc contents) of
     Just p -> Just (p, remainder)
     Nothing -> Nothing)
   Nothing -> Nothing
   
getObject l =
  case (unquote l nopen nclose) of
   Just (contents, remainder) -> (case (integerListToProc contents) of
     Just p -> Just (p, remainder)
     Nothing -> Nothing)
   Nothing -> Nothing

getParLeft l = 
  case (unquote l popen pclose) of
   Just (contents, remainder) -> (case (integerListToProc contents) of
     Just p -> Just (p, remainder)
     Nothing -> Nothing)
   Nothing -> Nothing

getContinuation l = 
  case (unquote l popen pclose) of
   Just (contents, []) -> (integerListToProc contents) of
   _ -> Nothing

getTransmission l = 
  case (unquote l popen pclose) of
   Just (contents, []) -> (integerListToProc contents) of
   _ -> Nothing

getParRight l = 
  case (unquote l popen pclose) of
   Just (contents, []) -> (integerListToProc contents) of
   _ -> Nothing

getNameCenter l = 
  case (unquote l nopen nclose) of
   Just (contents, []) -> (integerListToProc contents) of
   _ -> Nothing   

integerListToProc _ = Nothing

-- integerListToProc [] = Reflect Stop
-- integerListToProc (0:0:0:0:0) = Reflect Stop
-- integerListToProc (0:0:0:1:l) = Reflect (Input nx ny q)
--   where (nx,ny)  = ((Code px),(Code py))
--         (px,l')  = (getSubject l)
--         (py,l'') = (getObject l')
--         q        = (integerListToProc (getContinuation l'))
-- integerListToProc (0:0:1:0:l) = Reflect (Output nx q)
--   where nx      = (Code px)
--         (px,l') = (getSubject l)
--         q       = (integerListToProc (getTransmission l'))
-- integerListToProc (0:0:1:1:l) = Reflect (Par p q)
--   where (p,q)   = ((integerListToProc pl),(integerListToProc pr))
--         (pl,l') = (getParLeft l)
--         pr      = (getParRight l')
-- integerListToProc (0:1:0:0:l) = Reflect (Eval nx)
--   where nx = (Code (getNameCenter l)) 
\end{code}
