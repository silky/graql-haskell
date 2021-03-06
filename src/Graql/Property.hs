module Graql.Property
    ( Property (..)
    , Var
    , Name
    , VarOrName
    , Value (..)
    , IsVarOrName
    , IsRolePlayer
    , IsResource
    , var
    , name
    , (.:)
    , rp
    , toVarOrName
    , toRolePlayer
    , toResource
    ) where

import           Graql.Util
import           Data.Text        (Text, unpack)
import           Data.Scientific  (Scientific)
import           Text.Regex.Posix ((=~))
import           Control.Applicative (empty)
import           Data.Aeson       (FromJSON, FromJSONKey,
                                   FromJSONKeyFunction (FromJSONKeyText),
                                   parseJSON)
import qualified Data.Aeson       as Aeson

-- |A property of a concept
data Property = Isa VarOrName
              | NameProperty Name
              | Rel [RolePlayer]
              | Has Name (Either Value Var)

-- |A variable name wildcard that will represent a concept in the results
data Var = Var Text deriving (Eq, Ord)

-- |A name of something in the graph
data Name = Name Text

-- |Something that may be a variable name or a type name
data VarOrName = VarName Var | TypeName Name

-- |A value of a resource
data Value = ValueString Text | ValueNumber Scientific | ValueBool Bool

-- |A casting, relating a role type and role player
data RolePlayer = RolePlayer (Maybe VarOrName) Var

-- |Something that can be converted into a variable or a type name
class IsVarOrName a where
    toVarOrName :: a -> VarOrName

-- |Something that can be converted into a casting
class IsRolePlayer a where
    toRolePlayer :: a -> RolePlayer

-- |Something that can be converted into a resource value or variable
class IsResource a where
    toResource :: a -> Either Value Var

-- |Create a variable
var :: Text -> Var
var = Var

-- |Create a name of something in the graph
name :: Text -> Name
name = Name

-- |A casting in a relation between a role type and a role player
(.:) :: IsVarOrName a => a -> Var -> RolePlayer
rt .: player = RolePlayer (Just $ toVarOrName rt) player

-- |A casting in a relation without a role type
rp :: Var -> RolePlayer
rp = RolePlayer Nothing


nameRegex :: String
nameRegex = "^[a-zA-Z_][a-zA-Z0-9_-]*$"

instance Show Property where
    show (Isa varOrName ) = "isa " ++ show varOrName
    show (NameProperty n) = "type-name " ++ show n
    show (Rel castings  ) = "(" ++ commas castings ++ ")"
    show (Has rt value  ) = "has " ++ show rt ++ " " ++ showEither value

instance Show RolePlayer where
    show (RolePlayer roletype player) = roletype `with` ": " ++ show player

instance Show Value where
    show (ValueString text) = show text
    show (ValueNumber num ) = show num
    show (ValueBool   bool) = show bool

instance Show Name where
    show (Name text)
      | str =~ nameRegex = str
      | otherwise      = show text
        where str = unpack text

instance Show Var where
    show (Var v) = '$' : unpack v

instance Show VarOrName where
    show (VarName  v) = show v
    show (TypeName t) = show t

instance IsVarOrName Var where
    toVarOrName = VarName

instance IsVarOrName Name where
    toVarOrName = TypeName

instance IsRolePlayer RolePlayer where
    toRolePlayer = id

instance IsRolePlayer Var where
    toRolePlayer = rp

instance IsResource Var where
    toResource = Right

instance IsResource Text where
    toResource = Left . ValueString

instance IsResource Scientific where
    toResource = Left . ValueNumber

instance IsResource Bool where
    toResource = Left . ValueBool

instance FromJSON Value where
  parseJSON (Aeson.String s) = return $ ValueString s
  parseJSON (Aeson.Number n) = return $ ValueNumber n
  parseJSON (Aeson.Bool   b) = return $ ValueBool b
  parseJSON _                = empty

instance FromJSON Name where
  parseJSON (Aeson.String s) = return $ name s
  parseJSON _                = empty

instance FromJSON Var where
  parseJSON (Aeson.String s) = return $ var s
  parseJSON _                = empty

instance FromJSONKey Var where
  fromJSONKey = FromJSONKeyText var

showEither :: (Show a, Show b) => Either a b -> String
showEither = either show show
