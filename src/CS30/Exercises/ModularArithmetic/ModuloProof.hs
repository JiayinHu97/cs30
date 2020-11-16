{-# OPTIONS_GHC -Wall #-}

module CS30.Exercises.ModularArithmetic.ModuloProof where

import CS30.Exercises.ModularArithmetic.ModuloParser

-------------------------------------Laws----------------------------------------

_arithmetic_laws :: [Law]
_arithmetic_laws = map (parseLaw False)
                  [
                     "Multiplication_with_zero : x \\cdot 0 = 0"
                    ,"Multiplication_with_zero : 0 \\cdot x = 0"
                    ,"Addition_with_zero : x + 0 = x"
                    ,"Addition_with_zero : 0 + x = x"
                    ,"Subtraction_law : x - y = x + (-y)"
                    ,"Cancellation_law : x + (-x) = 0"
                    ,"Multiplication_with_one : x \\cdot 1 = x"
                    ,"Multiplication_with_one : 1 \\cdot x = x"
                    ,"Negation_law : x \\cdot -1 = -x"
                    ,"Negation_law : -1 \\cdot x = -x"
                    ,"Power_zero_law : x ^ 0 = 1"
                    ,"Power_one_law : 1 ^ x = 1"
                    ,"Multiplicative_distribution_on_addition : x \\cdot (y + z) = x \\cdot y + x \\cdot z"
                    ,"Multiplicative_distribution_on_subtraction : x \\cdot (y - z) = x \\cdot y - x \\cdot z"
                    ,"Multiplicative_distribution_on_addition : (x + y) \\cdot z = x \\cdot z + y \\cdot z"
                    ,"Multiplicative_distribution_on_subtraction : (x - y) \\cdot z = x \\cdot z - y \\cdot z"
                    ,"Distribution_on_addition_of_powers : x ^ (y + z) = x ^ y \\cdot x ^ z"
                    ,"Power_distribution_on_multiplication : (x \\cdot y) ^ z = x ^ z \\cdot y ^ z"
                  ]

-------------------------------------Proofs----------------------------------------

getDerivation :: Int -> [Law] -> Expression -> Proof
getDerivation steps laws e = Proof e (take steps (removeGiven fullPrf))
                             where fullPrf = getDerivationWithGiven (steps * 2) laws e
                                   removeGiven (Proof _ stps) = (filter (\stp -> fst stp /= "Given")) stps
                                   removeGiven ProofError = []

getDerivationWithGiven :: Int -> [Law] -> Expression -> Proof
getDerivationWithGiven steps laws e
  = Proof e (multiSteps steps e)
    where multiSteps 0 _ = [] -- [proofSteps]
          multiSteps steps' e'
            = case [ (lawName law, res) -- proofStep
                   | law <- laws -- Law
                   , res <- getStep (lawEq law) e' -- getStep
                   ] of
                       [] -> []
                       ((nm,e''):_) -> (nm,e'') : multiSteps (steps'-1) e''

getStep :: Equation -> Expression -> [Expression]
getStep (lhs, rhs) expr
  = case matchE lhs expr of
      Nothing -> recurse expr
      Just subst -> [apply subst rhs]
  where recurse (Var _) = []
        recurse (Con _) = []
        recurse (Fixed _) = []
        recurse (BinOp op e1 e2)
          = [BinOp op e1' e2 | e1' <- getStep (lhs,rhs) e1] ++
            [BinOp op e1 e2' | e2' <- getStep (lhs,rhs) e2]
        recurse (UnOp op e1)
          = [UnOp op e1' | e1' <- getStep (lhs,rhs) e1]
        recurse (ExpressionError) = []

matchE :: Expression -> Expression -> Maybe Substitution
matchE (Var nm) expr = Just [([nm],expr)]
matchE (Con i) (Con j) | i == j = Just []
matchE (Con _) _ = Nothing
matchE (Fixed i) (Fixed j) | i == j = Just []
matchE (Fixed _) _ = Nothing
matchE (BinOp op1 e1 e2) (BinOp op2 e3 e4) | op1 == op2
 = case (matchE e1 e3, matchE e2 e4) of
    (Just s1, Just s2) -> combineTwoSubsts s1 s2
    _ -> Nothing
matchE (BinOp _ _ _) _ = Nothing
matchE (UnOp Neg e1) (UnOp Neg e2) = matchE e1 e2
matchE (UnOp _ _) _ = Nothing
matchE ExpressionError _ = Nothing

combineTwoSubsts :: Substitution -> Substitution -> Maybe Substitution
combineTwoSubsts s1 s2
  = case and [v1 == v2 | (nm1,v1) <- s1, (nm2,v2) <- s2, nm1 == nm2] of
     True -> Just (s1 ++ s2)
     False -> Nothing

apply :: Substitution -> Expression -> Expression
apply subst (Var nm) = lookupInSubst [nm] subst
apply _ (Con i) = Con i
apply _ (Fixed i) = Fixed i
apply subst (UnOp op e) = UnOp op (apply subst e)
apply subst (BinOp op e1 e2) = BinOp op (apply subst e1) (apply subst e2)
apply _ ExpressionError = ExpressionError

lookupInSubst :: String -> [(String, Expression)] -> Expression
lookupInSubst nm ((nm',v):rm)
 | nm == nm' = v
 | otherwise = lookupInSubst nm rm
lookupInSubst _ [] = error "Substitution was not complete, or free variables existed in the rhs of some equality"

-------------------------------------Evaluation----------------------------------------

evalExpression :: Substitution -> Int -> Expression -> Maybe Int
evalExpression s p = evalExpression' p . evalApply s

evalExpression' :: Int -> Expression -> Maybe Int
evalExpression' p (Con i) = modulo p (Just i)
evalExpression' p (UnOp op e) = modulo p (fnOp op (evalExpression' p e) Nothing)
evalExpression' p (BinOp op e1 e2) = modulo p (fnOp op (evalExpression' p e1) (evalExpression' p e2))
evalExpression' _ _ = Nothing

fnOp :: Op -> Maybe Int -> Maybe Int -> Maybe Int
fnOp Neg (Just x) _ = Just (-x)
fnOp Pow (Just 0) (Just 0) = Nothing
fnOp op (Just x) (Just y) = Just (opVal x y)
                              where opVal = case op of {Pow -> (^); Mul -> (*); Sub -> (-); Add -> (+); _ -> (+)}
fnOp _ _ _ = Nothing

modulo :: Int -> Maybe Int -> Maybe Int
modulo p (Just x) = Just (x `mod` p)
modulo _ _ = Nothing

evalApply :: Substitution -> Expression -> Expression
evalApply subst (Var nm) = lookupInSubst [nm] subst
evalApply _ (Con x) = Con x
evalApply subst (Fixed nm) = lookupInSubst [nm] subst
evalApply subst (UnOp op e) = UnOp op (evalApply subst e)
evalApply subst (BinOp op e1 e2) = BinOp op (evalApply subst e1) (evalApply subst e2)
evalApply _ _ = ExpressionError

getVariables :: Expression -> [Char]
getVariables (Var x) = [x]
getVariables (Fixed x) = [x]
getVariables (Con _) = []
getVariables (UnOp _ e) = dedup (getVariables e)
getVariables (BinOp _ e1 e2) = dedup (getVariables e1 ++ getVariables e2)
getVariables _ = []

dedup :: Eq a => [a] -> [a]
dedup [] = []
dedup (x:xs) = if elem x xs 
               then dedup xs 
               else [x] ++ dedup xs 

-------------------------------------Tests----------------------------------------

testLaw :: Law -> Bool
testLaw (Law _ (lhs, rhs)) = and [ evalExpression subst 101 lhs == evalExpression subst 101 rhs 
                                  | x <- [2,3,4],
                                    y <- [2,3,4],
                                    z <- [2,3,4],
                                  let subst = [("x", Con x), ("y", Con y), ("z", Con z)]]
testLaw LawError = False

_exp :: Expression
_exp = parseExpression True "(a \\cdot 3) ^ b \\cdot (c + d)"

_subst :: Substitution
_subst = [("a", Con 3), ("b", Con 2), ("c", Con 1), ("d", Con 4)]

_eval :: Maybe Int
_eval = evalExpression _subst 10 _exp

_given :: Law
_given = parseLaw True "given : a = b ^ b"

_prf :: Proof
_prf = getDerivation 5 (_given:_arithmetic_laws) _exp
