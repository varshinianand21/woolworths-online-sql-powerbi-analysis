# Woolworths Online (Melbourne) – Simulated Dataset

> **Disclaimer:** This is a *simulated* dataset created for a portfolio case study. It is modelled on publicly known features of Woolworths' online service (Everyday Rewards, Delivery Unlimited, Direct to Boot, own-brand range) and uses real Melbourne suburbs and postcodes. It contains no real Woolworths data and is not affiliated with Woolworths Group.

**Period:** Jan 2024 – Dec 2025 · **Currency:** AUD · **Area:** Melbourne metro

## Tables

### customers.csv (7,000 rows) – one row per customer
| Column | Description |
|---|---|
| customer_id | Primary key (C00001…) |
| signup_date | Date the customer created their online account |
| suburb, postcode | Delivery suburb (real Melbourne suburbs) |
| region | Inner, North, West, East, South East |
| age_band | 18-24 … 65+ |
| everyday_rewards_member | Y/N – loyalty program member |
| delivery_unlimited_member | Y/N – paid delivery subscription |

### stores.csv (10 rows) – fulfilment stores that pick online orders
| store_id | store_name | region | store_format (Metro / Supermarket) |

### products.csv (132 rows)
| Column | Description |
|---|---|
| product_id | Primary key |
| product_name | Product description |
| department | Fruit & Veg, Meat & Seafood, Dairy Eggs & Fridge, Bakery, Pantry, Freezer, Drinks, Snacks & Confectionery, Household, Health & Beauty, Baby, Pet |
| brand_type | Branded / Woolworths Own Brand |
| unit_price | Shelf price (AUD) |

### orders.csv (~60,000 rows) – one row per online order
| Column | Description |
|---|---|
| order_id | Order key (O000001…) |
| customer_id | FK → customers |
| store_id | FK → stores (store that picked the order) |
| order_datetime | When the order was placed |
| fulfilment_type | Home Delivery / Pick up / Direct to Boot |
| order_status | Completed / Cancelled |
| basket_value_aud | Value of items supplied, after item discounts, excl. delivery fee |
| delivery_fee_aud | Fee charged |
| promo_code | e.g. FIRSTORDER (blank if none) |
| rewards_points_earned | Everyday Rewards points (1 per $1, members only) |
| rewards_dollars_redeemed | $ of rewards redeemed on the order |

### order_items.csv (~680,000 rows) – one row per product line in an order
| Column | Description |
|---|---|
| order_id | FK → orders |
| product_id | FK → products (item ordered) |
| quantity | Units ordered |
| unit_price_aud | Price per unit |
| discount_aud | Specials discount on the line |
| pick_status | Picked / Substituted / Unavailable |
| substitute_product_id | FK → products, product supplied instead (if substituted) |

### deliveries.csv (~44,000 rows) – home delivery orders only
| Column | Description |
|---|---|
| order_id | FK → orders |
| window_start, window_end | Promised 3-hour delivery window |
| delivered_at | Actual delivery time |
| delivery_status | On Time / Late / Cancelled |
| minutes_late | Minutes after window end (0 if on time) |

### customer_feedback.csv (~25,000 rows) – post-order ratings (not every order is rated)
| Column | Description |
|---|---|
| order_id | FK → orders |
| feedback_date | Date of feedback |
| rating | 1–5 stars |
| complaint_reason | Poor substitution, Missing item, Late delivery, Damaged item, Fresh produce quality (blank if none) |
| refund_aud | Refund/credit issued |

## Relationships
customers 1─* orders *─1 stores · orders 1─* order_items *─1 products · orders 1─0..1 deliveries · orders 1─0..1 customer_feedback

## Note
Like real company data, this dataset contains **data quality issues** (duplicates, inconsistent text values, missing values). Finding and handling them is part of the project.
