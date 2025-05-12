/*
  # Initial Schema for AngiDay Meal Planner

  1. New Tables
    - `profiles`: User profiles with preferences
    - `recipes`: Recipe details and metadata
    - `recipe_ingredients`: Ingredients for each recipe
    - `meal_plans`: User meal plans
    - `meal_plan_items`: Individual items in meal plans
    - `shopping_lists`: Shopping lists
    - `shopping_list_items`: Items in shopping lists
    - `recipe_tags`: Tags for recipes
    - `tags`: Tag definitions

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Anyone can view public recipes" ON recipes;
DROP POLICY IF EXISTS "Users can create recipes" ON recipes;
DROP POLICY IF EXISTS "Users can update their own recipes" ON recipes;
DROP POLICY IF EXISTS "Users can view recipe ingredients" ON recipe_ingredients;
DROP POLICY IF EXISTS "Users can manage their recipe ingredients" ON recipe_ingredients;
DROP POLICY IF EXISTS "Anyone can view tags" ON tags;
DROP POLICY IF EXISTS "Anyone can view recipe tags" ON recipe_tags;
DROP POLICY IF EXISTS "Users can manage their recipe tags" ON recipe_tags;
DROP POLICY IF EXISTS "Users can manage their meal plans" ON meal_plans;
DROP POLICY IF EXISTS "Users can manage their meal plan items" ON meal_plan_items;
DROP POLICY IF EXISTS "Users can manage their shopping lists" ON shopping_lists;
DROP POLICY IF EXISTS "Users can manage their shopping list items" ON shopping_list_items;

-- Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text UNIQUE,
  full_name text,
  avatar_url text,
  dietary_preferences jsonb DEFAULT '[]',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tags table for recipe categorization
CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL, -- cuisine, course, dietary, ingredient, method, difficulty
  created_at timestamptz DEFAULT now()
);

-- Recipes table
CREATE TABLE IF NOT EXISTS recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  title text NOT NULL,
  description text,
  instructions text[] NOT NULL,
  prep_time_minutes integer,
  cook_time_minutes integer,
  servings integer,
  difficulty text,
  estimated_cost decimal(10,2),
  calories_per_serving integer,
  image_url text,
  source_url text,
  source_name text,
  is_public boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Recipe ingredients
CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id uuid REFERENCES recipes(id) ON DELETE CASCADE,
  name text NOT NULL,
  amount decimal(10,2),
  unit text,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Recipe tags
CREATE TABLE IF NOT EXISTS recipe_tags (
  recipe_id uuid REFERENCES recipes(id) ON DELETE CASCADE,
  tag_id uuid REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (recipe_id, tag_id)
);

-- Meal plans
CREATE TABLE IF NOT EXISTS meal_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  title text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Meal plan items
CREATE TABLE IF NOT EXISTS meal_plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id uuid REFERENCES meal_plans(id) ON DELETE CASCADE,
  recipe_id uuid REFERENCES recipes(id),
  date date NOT NULL,
  meal_type text NOT NULL, -- breakfast, lunch, dinner, snack
  servings integer DEFAULT 1,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Shopping lists
CREATE TABLE IF NOT EXISTS shopping_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  title text NOT NULL,
  meal_plan_id uuid REFERENCES meal_plans(id),
  is_completed boolean DEFAULT false,
  total_cost decimal(10,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Shopping list items
CREATE TABLE IF NOT EXISTS shopping_list_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shopping_list_id uuid REFERENCES shopping_lists(id) ON DELETE CASCADE,
  ingredient_name text NOT NULL,
  amount decimal(10,2),
  unit text,
  is_checked boolean DEFAULT false,
  category text, -- produce, meat, dairy, etc.
  estimated_cost decimal(10,2),
  actual_cost decimal(10,2),
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plan_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_list_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;

-- Policies

-- Profiles
CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Recipes
CREATE POLICY "Anyone can view public recipes"
  ON recipes FOR SELECT
  TO authenticated
  USING (is_public = true OR auth.uid() = user_id);

CREATE POLICY "Users can create recipes"
  ON recipes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own recipes"
  ON recipes FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Recipe ingredients
CREATE POLICY "Users can view recipe ingredients"
  ON recipe_ingredients FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM recipes
      WHERE recipes.id = recipe_ingredients.recipe_id
      AND (recipes.is_public = true OR recipes.user_id = auth.uid())
    )
  );

CREATE POLICY "Users can manage their recipe ingredients"
  ON recipe_ingredients FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM recipes
      WHERE recipes.id = recipe_ingredients.recipe_id
      AND recipes.user_id = auth.uid()
    )
  );

-- Tags
CREATE POLICY "Anyone can view tags"
  ON tags FOR SELECT
  TO authenticated
  USING (true);

-- Recipe tags
CREATE POLICY "Anyone can view recipe tags"
  ON recipe_tags FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can manage their recipe tags"
  ON recipe_tags FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM recipes
      WHERE recipes.id = recipe_tags.recipe_id
      AND recipes.user_id = auth.uid()
    )
  );

-- Meal plans
CREATE POLICY "Users can manage their meal plans"
  ON meal_plans FOR ALL
  TO authenticated
  USING (auth.uid() = user_id);

-- Meal plan items
CREATE POLICY "Users can manage their meal plan items"
  ON meal_plan_items FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM meal_plans
      WHERE meal_plans.id = meal_plan_items.meal_plan_id
      AND meal_plans.user_id = auth.uid()
    )
  );

-- Shopping lists
CREATE POLICY "Users can manage their shopping lists"
  ON shopping_lists FOR ALL
  TO authenticated
  USING (auth.uid() = user_id);

-- Shopping list items
CREATE POLICY "Users can manage their shopping list items"
  ON shopping_list_items FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM shopping_lists
      WHERE shopping_lists.id = shopping_list_items.shopping_list_id
      AND shopping_lists.user_id = auth.uid()
    )
  );