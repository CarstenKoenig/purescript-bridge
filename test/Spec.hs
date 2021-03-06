{-# LANGUAGE CPP                   #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module Main where
import qualified Data.Map                                  as Map
import           Data.Monoid                               ((<>))
import           Data.Proxy
import qualified Data.Text                                 as T
import           Language.PureScript.Bridge
import           Language.PureScript.Bridge.TypeParameters
import           Language.PureScript.Bridge.CodeGenSwitches
import           Test.Hspec                                (Spec, describe,
                                                            hspec, it)
import           Test.Hspec.Expectations.Pretty
import           TestData

main :: IO ()
main = hspec allTests


allTests :: Spec
allTests = do
  describe "buildBridge" $ do
    let settings = defaultSettings
    it "tests with Int" $
      let bst = buildBridge defaultBridge (mkTypeInfo (Proxy :: Proxy Int))
          ti  = TypeInfo { _typePackage    = ""
                       , _typeModule     = "Prim"
                       , _typeName       = "Int"
                       , _typeParameters = []}
       in bst `shouldBe` ti
    it "tests with custom type Foo" $
      let prox = Proxy :: Proxy Foo
          bst = bridgeSumType (buildBridge defaultBridge) (order prox $ mkSumType prox)
          st = SumType
                TypeInfo { _typePackage = "" , _typeModule = "TestData" , _typeName = "Foo" , _typeParameters = [] }
                [ DataConstructor { _sigConstructor = "Foo" , _sigValues = Left [] }
                , DataConstructor
                  { _sigConstructor = "Bar"
                  , _sigValues = Left [ TypeInfo { _typePackage = "" , _typeModule = "Prim" , _typeName = "Int" , _typeParameters = [] } ]
                  }
                , DataConstructor
                  { _sigConstructor = "FooBar"
                  , _sigValues = Left [ TypeInfo { _typePackage = "" , _typeModule = "Prim" , _typeName = "Int" , _typeParameters = [] }
                                      , TypeInfo { _typePackage = "" , _typeModule = "Prim" , _typeName = "String" , _typeParameters = [] }
                                      ]
                  }
                ]
                [Eq, Ord, Generic]
       in bst `shouldBe` st
    it "tests generation of for custom type Foo" $
     let prox = Proxy :: Proxy Foo
         recType = bridgeSumType (buildBridge defaultBridge) (order prox $ mkSumType prox)
         recTypeText = sumTypeToText settings recType
         txt = T.stripEnd $
               T.unlines [ "data Foo ="
                         , "    Foo"
                         , "  | Bar Int"
                         , "  | FooBar Int String"
                         , ""
                         , "derive instance eqFoo :: Eq Foo"
                         , "derive instance ordFoo :: Ord Foo"
                         , "derive instance genericFoo :: Generic Foo"
                         , ""
                         , "--------------------------------------------------------------------------------"
                         , "_Foo :: Prism' Foo Unit"
                         , "_Foo = prism' (\\_ -> Foo) f"
                         , "  where"
                         , "    f Foo = Just unit"
                         , "    f _ = Nothing"
                         , ""
                         , "_Bar :: Prism' Foo Int"
                         , "_Bar = prism' Bar f"
                         , "  where"
                         , "    f (Bar a) = Just $ a"
                         , "    f _ = Nothing"
                         , ""
                         , "_FooBar :: Prism' Foo { a :: Int, b :: String }"
                         , "_FooBar = prism' (\\{ a, b } -> FooBar a b) f"
                         , "  where"
                         , "    f (FooBar a b) = Just $ { a: a, b: b }"
                         , "    f _ = Nothing"
                         , ""
                         , "--------------------------------------------------------------------------------"
                         ]
     in recTypeText `shouldBe` txt
    it "tests the generation of a whole (dummy) module" $
      let advanced = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (Bar A B M1 C)))
          modules = sumTypeToModule advanced Map.empty
          m = head . map (moduleToText settings) . Map.elems $ modules
          txt = T.unlines [ "-- File auto generated by purescript-bridge! --"
                          , "module TestData where"
                          , ""
                          , "import Data.Either (Either)"
                          , "import Data.Lens (Iso', Lens', Prism', lens, prism')"
                          , "import Data.Lens.Iso.Newtype (_Newtype)"
                          , "import Data.Lens.Record (prop)"
                          , "import Data.Maybe (Maybe, Maybe(..))"
                          , "import Data.Newtype (class Newtype)"
                          , "import Data.Symbol (SProxy(SProxy))"
                          , ""
                          , "import Prelude"
                          , "import Data.Generic (class Generic)"
                          , ""
                          , "data Bar a b m c ="
                          , "    Bar1 (Maybe a)"
                          , "  | Bar2 (Either a b)"
                          , "  | Bar3 a"
                          , "  | Bar4 {"
                          , "      myMonadicResult :: m b"
                          , "    }"
                          , ""
                          , "derive instance genericBar :: (Generic a, Generic b, Generic (m b)) => Generic (Bar a b m c)"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          , "_Bar1 :: forall a b m c. Prism' (Bar a b m c) (Maybe a)"
                          , "_Bar1 = prism' Bar1 f"
                          , "  where"
                          , "    f (Bar1 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar2 :: forall a b m c. Prism' (Bar a b m c) (Either a b)"
                          , "_Bar2 = prism' Bar2 f"
                          , "  where"
                          , "    f (Bar2 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar3 :: forall a b m c. Prism' (Bar a b m c) a"
                          , "_Bar3 = prism' Bar3 f"
                          , "  where"
                          , "    f (Bar3 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar4 :: forall a b m c. Prism' (Bar a b m c) { myMonadicResult :: m b }"
                          , "_Bar4 = prism' Bar4 f"
                          , "  where"
                          , "    f (Bar4 r) = Just r"
                          , "    f _ = Nothing"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          ]
      in m `shouldBe` txt
    it "test generation of constructor optics" $
      let bar = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (Bar A B M1 C)))
          foo = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy Foo))
          barOptics = constructorOptics bar
          fooOptics = constructorOptics foo
          txt = T.unlines [
                            "_Bar1 :: forall a b m c. Prism' (Bar a b m c) (Maybe a)"
                          , "_Bar1 = prism' Bar1 f"
                          , "  where"
                          , "    f (Bar1 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar2 :: forall a b m c. Prism' (Bar a b m c) (Either a b)"
                          , "_Bar2 = prism' Bar2 f"
                          , "  where"
                          , "    f (Bar2 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar3 :: forall a b m c. Prism' (Bar a b m c) a"
                          , "_Bar3 = prism' Bar3 f"
                          , "  where"
                          , "    f (Bar3 a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar4 :: forall a b m c. Prism' (Bar a b m c) { myMonadicResult :: m b }"
                          , "_Bar4 = prism' Bar4 f"
                          , "  where"
                          , "    f (Bar4 r) = Just r"
                          , "    f _ = Nothing"
                          , ""
                          , "_Foo :: Prism' Foo Unit"
                          , "_Foo = prism' (\\_ -> Foo) f"
                          , "  where"
                          , "    f Foo = Just unit"
                          , "    f _ = Nothing"
                          , ""
                          , "_Bar :: Prism' Foo Int"
                          , "_Bar = prism' Bar f"
                          , "  where"
                          , "    f (Bar a) = Just $ a"
                          , "    f _ = Nothing"
                          , ""
                          , "_FooBar :: Prism' Foo { a :: Int, b :: String }"
                          , "_FooBar = prism' (\\{ a, b } -> FooBar a b) f"
                          , "  where"
                          , "    f (FooBar a b) = Just $ { a: a, b: b }"
                          , "    f _ = Nothing"
                          , ""
                          ]
      in (barOptics <> fooOptics) `shouldBe` txt
    it "tests generation of record optics" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (SingleRecord A B)))
          bar = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (Bar A B M1 C)))
          barOptics = recordOptics bar
          recTypeOptics = recordOptics recType
          txt = T.unlines [
                            "a :: forall a b. Lens' (SingleRecord a b) a"
                          , "a = _Newtype <<< prop (SProxy :: SProxy \"_a\")"
                          , ""
                          , "b :: forall a b. Lens' (SingleRecord a b) b"
                          , "b = _Newtype <<< prop (SProxy :: SProxy \"_b\")"
                          , ""
                          ]
      in (barOptics <> recTypeOptics) `shouldBe` txt
    it "tests generation of newtypes for record data type" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (SingleRecord A B)))
          recTypeText = sumTypeToText settings recType
          txt = T.stripEnd $
                T.unlines [ "newtype SingleRecord a b ="
                          , "    SingleRecord {"
                          , "      _a :: a"
                          , "    , _b :: b"
                          , "    , c :: String"
                          , "    }"
                          , ""
                          , "derive instance genericSingleRecord :: (Generic a, Generic b) => Generic (SingleRecord a b)"
                          , "derive instance newtypeSingleRecord :: Newtype (SingleRecord a b) _"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          , "_SingleRecord :: forall a b. Iso' (SingleRecord a b) { _a :: a, _b :: b, c :: String}"
                          , "_SingleRecord = _Newtype"
                          ,""
                          , "a :: forall a b. Lens' (SingleRecord a b) a"
                          , "a = _Newtype <<< prop (SProxy :: SProxy \"_a\")"
                          , ""
                          , "b :: forall a b. Lens' (SingleRecord a b) b"
                          , "b = _Newtype <<< prop (SProxy :: SProxy \"_b\")"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation of newtypes for haskell newtype" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SomeNewtype))
          recTypeText = sumTypeToText settings recType
          txt = T.stripEnd $
                T.unlines [ "newtype SomeNewtype ="
                          , "    SomeNewtype Int"
                          , ""
                          , "derive instance genericSomeNewtype :: Generic SomeNewtype"
                          , "derive instance newtypeSomeNewtype :: Newtype SomeNewtype _"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          , "_SomeNewtype :: Iso' SomeNewtype Int"
                          , "_SomeNewtype = _Newtype"
                          , "--------------------------------------------------------------------------------"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation of newtypes for haskell data type with one argument" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SingleValueConstr))
          recTypeText = sumTypeToText settings recType
          txt = T.stripEnd $
                T.unlines [ "newtype SingleValueConstr ="
                          , "    SingleValueConstr Int"
                          , ""
                          , "derive instance genericSingleValueConstr :: Generic SingleValueConstr"
                          , "derive instance newtypeSingleValueConstr :: Newtype SingleValueConstr _"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          , "_SingleValueConstr :: Iso' SingleValueConstr Int"
                          , "_SingleValueConstr = _Newtype"
                          , "--------------------------------------------------------------------------------"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation for haskell data type with one constructor, two arguments" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SingleProduct))
          recTypeText = sumTypeToText settings recType
          txt = T.stripEnd $
                T.unlines [ "data SingleProduct ="
                          , "    SingleProduct String Int"
                          , ""
                          , "derive instance genericSingleProduct :: Generic SingleProduct"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          , "_SingleProduct :: Prism' SingleProduct { a :: String, b :: Int }"
                          , "_SingleProduct = prism' (\\{ a, b } -> SingleProduct a b) f"
                          , "  where"
                          , "    f (SingleProduct a b) = Just $ { a: a, b: b }"
                          , ""
                          , "--------------------------------------------------------------------------------"
                          ]
      in recTypeText `shouldBe` txt
    it "tests that sum types with multiple constructors don't generate record optics" $
      let recType = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy TwoRecords))
          recTypeOptics = recordOptics recType
      in recTypeOptics `shouldBe` "" -- No record optics for multi-constructors

  describe "buildBridge without lens-code-gen" $ do
    let settings = getSettings noLenses
    it "tests generation of for custom type Foo" $
      let proxy = Proxy :: Proxy Foo
          recType = bridgeSumType (buildBridge defaultBridge) (order proxy $ mkSumType proxy)
          recTypeText = sumTypeToText settings recType
          txt = T.unlines [ "data Foo ="
                          , "    Foo"
                          , "  | Bar Int"
                          , "  | FooBar Int String"
                          , ""
                          , "derive instance eqFoo :: Eq Foo"
                          , "derive instance ordFoo :: Ord Foo"
                          , "derive instance genericFoo :: Generic Foo"
                          ]
      in recTypeText `shouldBe` txt
    it "tests the generation of a whole (dummy) module" $
      let advanced' = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (Bar A B M1 C)))
          modules = sumTypeToModule advanced' Map.empty
          m = head . map (moduleToText settings) . Map.elems $ modules
          txt = T.unlines [ "-- File auto generated by purescript-bridge! --"
                          , "module TestData where"
                          , ""
                          , "import Data.Either (Either)"
                          , "import Data.Maybe (Maybe, Maybe(..))"
                          , "import Data.Newtype (class Newtype)"
                          , ""
                          , "import Prelude"
                          , "import Data.Generic (class Generic)"
                          , ""
                          , "data Bar a b m c ="
                          , "    Bar1 (Maybe a)"
                          , "  | Bar2 (Either a b)"
                          , "  | Bar3 a"
                          , "  | Bar4 {"
                          , "      myMonadicResult :: m b"
                          , "    }"
                          , ""
                          , "derive instance genericBar :: (Generic a, Generic b, Generic (m b)) => Generic (Bar a b m c)"
                          , ""
                          ]
      in m `shouldBe` txt
    it "tests generation of newtypes for record data type" $
      let recType' = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy (SingleRecord A B)))
          recTypeText = sumTypeToText settings recType'
          txt = T.unlines [ "newtype SingleRecord a b ="
                          , "    SingleRecord {"
                          , "      _a :: a"
                          , "    , _b :: b"
                          , "    , c :: String"
                          , "    }"
                          , ""
                          , "derive instance genericSingleRecord :: (Generic a, Generic b) => Generic (SingleRecord a b)"
                          , "derive instance newtypeSingleRecord :: Newtype (SingleRecord a b) _"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation of newtypes for haskell newtype" $
      let recType' = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SomeNewtype))
          recTypeText = sumTypeToText settings recType'
          txt = T.unlines [ "newtype SomeNewtype ="
                          , "    SomeNewtype Int"
                          , ""
                          , "derive instance genericSomeNewtype :: Generic SomeNewtype"
                          , "derive instance newtypeSomeNewtype :: Newtype SomeNewtype _"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation of newtypes for haskell data type with one argument" $
      let recType' = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SingleValueConstr))
          recTypeText = sumTypeToText settings recType'
          txt = T.unlines [ "newtype SingleValueConstr ="
                          , "    SingleValueConstr Int"
                          , ""
                          , "derive instance genericSingleValueConstr :: Generic SingleValueConstr"
                          , "derive instance newtypeSingleValueConstr :: Newtype SingleValueConstr _"
                          ]
      in recTypeText `shouldBe` txt
    it "tests generation for haskell data type with one constructor, two arguments" $
      let recType' = bridgeSumType (buildBridge defaultBridge) (mkSumType (Proxy :: Proxy SingleProduct))
          recTypeText = sumTypeToText settings recType'
          txt = T.unlines [ "data SingleProduct ="
                          , "    SingleProduct String Int"
                          , ""
                          , "derive instance genericSingleProduct :: Generic SingleProduct"
                          ]
      in recTypeText `shouldBe` txt
 