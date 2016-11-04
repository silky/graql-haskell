module Graql.Query
    ( MatchQuery
    , Pattern
    , Value (..)
    , Var
    , Id
    , match
    , select
    , limit
    , distinct
    , isa
    , rel
    , has
    , (.:)
    , gid
    , var
    , anon
    , (<:)
    ) where

import           Data.List       (intercalate)
import           Data.Scientific (Scientific)
import           Data.Text       (Text, unpack)

newtype Id = Id Text

newtype Var = Var Text deriving (Eq, Ord)

data Value = ValueString Text | ValueNumber Scientific | ValueBool Bool

data VarOrId = VarName Var | IdName Id

data MatchQuery = Match [Pattern]
                | Select MatchQuery [Var]
                | Limit MatchQuery Integer
                | Distinct MatchQuery

data Pattern = VarPattern (Maybe VarOrId) [Property]
             | Disjunction Pattern Pattern
             | Conjunction [Pattern]

data Property = Isa VarOrId
              | IdProperty Id
              | Rel [Casting]
              | Has Id (Either Value Var)

data Casting = Casting (Maybe VarOrId) VarOrId

class IsVarOrId a where
    toVarOrId :: a -> VarOrId

instance IsVarOrId Var where
    toVarOrId = VarName

instance IsVarOrId Id where
    toVarOrId = IdName

class IsCasting a where
    toCasting :: a -> Casting

instance IsCasting Casting where
    toCasting = id

instance IsCasting VarOrId where
    toCasting = Casting Nothing

instance IsCasting Var where
    toCasting = toCasting . VarName

class IsResource a where
    toResource :: a -> Either Value Var

instance IsResource Var where
    toResource = Right

instance IsResource Text where
    toResource = Left . ValueString

instance IsResource Scientific where
    toResource = Left . ValueNumber

instance IsResource Bool where
    toResource = Left . ValueBool

instance Show Id where
    show (Id text) = unpack text

instance Show Var where
    show (Var v) = '$' : unpack v

instance Show VarOrId where
    show (VarName var) = show var
    show (IdName i)    = show i

instance Show MatchQuery where
    show (Match patts) = "match " ++ interList " " patts
    show (Select mq vars ) = show mq ++ " select " ++ commas vars ++ ";"
    show (Limit mq limit ) = show mq ++ " limit " ++ show limit ++ ";"
    show (Distinct mq    ) = show mq ++ " distinct;"

instance Show Pattern where
    show (VarPattern (Just var) props) = show var ++ " " ++ commas props ++ ";"
    show (VarPattern Nothing    props) = commas props ++ ";"
    show (Disjunction l r            ) = show l ++ " or " ++ show r ++ ";"
    show (Conjunction patts          ) = "{" ++ interList " " patts ++  "};"

instance Show Property where
    show (Isa varOrId         ) = "isa " ++ show varOrId
    show (IdProperty i        ) = "id " ++ show i
    show (Rel castings        ) = "(" ++ commas castings ++ ")"
    show (Has rt (Left  value)) = "has " ++ show rt ++ " " ++ show value
    show (Has rt (Right var  )) = "has " ++ show rt ++ " " ++ show var

instance Show Casting where
    show (Casting (Just rt) rp) = show rt ++ ": " ++ show rp
    show (Casting Nothing   rp) = show rp

instance Show Value where
    show (ValueString text) = show text
    show (ValueNumber num ) = show num
    show (ValueBool   bool) = show bool

commas :: Show a => [a] -> String
commas = interList ", "

interList :: Show a => String -> [a] -> String
interList sep = intercalate sep . map show

match :: [Pattern] -> MatchQuery
match = Match

select :: MatchQuery -> [Var] -> MatchQuery
select = Select

limit :: MatchQuery -> Integer -> MatchQuery
limit = Limit

distinct :: MatchQuery -> MatchQuery
distinct = Distinct

isa :: Id -> Property
isa = Isa . IdName

rel :: IsCasting a => [a] -> Property
rel = Rel . map toCasting

has :: IsResource a => Id -> a -> Property
has rt = Has rt . toResource

(.:) :: (IsVarOrId a, IsVarOrId b) => a -> b -> Casting
rt .: rp = Casting (Just $ toVarOrId rt) (toVarOrId rp)

gid :: Text -> Id
gid = Id

var :: Text -> Var
var = Var

anon :: [Property] -> Pattern
anon = VarPattern Nothing

(<:) :: IsVarOrId a => a -> [Property] -> Pattern
var <: ps = VarPattern (Just $ toVarOrId var) ps