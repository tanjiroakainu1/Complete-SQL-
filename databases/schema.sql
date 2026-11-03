-- ============================================================================
-- DATABASE CREATION & SETUP FOR AGAPE COFFEE SYSTEM
-- Platform: MySQL / MariaDB (XAMPP Compatible)
-- Includes Extended User Management, Normalized Address Details, & Stored Procedures
-- ============================================================================

-- Drop existing procedures to allow clean re-execution
DROP PROCEDURE IF EXISTS `sp_AddUser`;
DROP PROCEDURE IF EXISTS `sp_EditUser`;
DROP PROCEDURE IF EXISTS `sp_SoftDeleteUser`;
DROP PROCEDURE IF EXISTS `sp_AddMenuItem`;
DROP PROCEDURE IF EXISTS `sp_EditMenuItem`;
DROP PROCEDURE IF EXISTS `sp_SoftDeleteMenuItem`;

-- Drop existing tables to allow clean re-execution
DROP TABLE IF EXISTS `audit_trails`;
DROP TABLE IF EXISTS `archived_records`;
DROP TABLE IF EXISTS `chat_messages`;
DROP TABLE IF EXISTS `chat_conversations`;
DROP TABLE IF EXISTS `rider_locations`;
DROP TABLE IF EXISTS `pos_documentation_logs`;
DROP TABLE IF EXISTS `order_items`;
DROP TABLE IF EXISTS `food_orders`;
DROP TABLE IF EXISTS `recipe_ingredients`;
DROP TABLE IF EXISTS `ingredient_inventories`;
DROP TABLE IF EXISTS `inventory_categories`;
DROP TABLE IF EXISTS `menu_items`;
DROP TABLE IF EXISTS `menu_categories`;
DROP TABLE IF EXISTS `live_queues`;
DROP TABLE IF EXISTS `table_reservations`;
DROP TABLE IF EXISTS `agape_tables`;
DROP TABLE IF EXISTS `customer_addresses`;
DROP TABLE IF EXISTS `staff_profiles`;
DROP TABLE IF EXISTS `user_credentials`;
DROP TABLE IF EXISTS `system_users`;
DROP TABLE IF EXISTS `user_roles`;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 1. EXTENDED USER MANAGEMENT MODULE (RBAC, PROFILES, & ADDRESSES)
-- ============================================================================

-- Role Table: Defines permissions for Admin, Manager, Frontdesk, Kitchen, Rider, Customer
CREATE TABLE `user_roles` (
  `role_id` INT AUTO_INCREMENT PRIMARY KEY,
  `role_name` VARCHAR(50) NOT NULL UNIQUE,
  `description` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Master System Users Table
CREATE TABLE `system_users` (
  `user_id` INT AUTO_INCREMENT PRIMARY KEY,
  `role_id` INT NOT NULL,
  `first_name` VARCHAR(100) NOT NULL,
  `last_name` VARCHAR(100) NOT NULL,
  `email` VARCHAR(150) NOT NULL UNIQUE,
  `phone_number` VARCHAR(20) NOT NULL UNIQUE,
  `status` ENUM('Active', 'Inactive', 'Suspended', 'Archived') NOT NULL DEFAULT 'Active',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_users_role` FOREIGN KEY (`role_id`) REFERENCES `user_roles` (`role_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- User Credentials & Security Settings (Handles Logins, Passwords, MFA)
CREATE TABLE `user_credentials` (
  `credential_id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `mfa_secret` VARCHAR(100) NULL,
  `mfa_enabled` TINYINT(1) DEFAULT 0,
  `reset_token` VARCHAR(255) NULL,
  `reset_token_expires` DATETIME NULL,
  `last_login_at` DATETIME NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_credentials_user` FOREIGN KEY (`user_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Extended Staff Profiles (Includes Full Residential Address Details)
CREATE TABLE `staff_profiles` (
  `staff_profile_id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL UNIQUE,
  `employee_id_number` VARCHAR(50) NOT NULL UNIQUE,
  `department` ENUM('Management', 'Frontdesk', 'Kitchen', 'Logistics') NOT NULL,
  `hire_date` DATE NOT NULL,
  `house_building_no` VARCHAR(100) NULL,
  `street_address` TEXT NOT NULL,
  `barangay` VARCHAR(100) NOT NULL DEFAULT 'Nazareth',
  `city_municipality` VARCHAR(100) NOT NULL DEFAULT 'Cagayan de Oro City',
  `province` VARCHAR(100) NOT NULL DEFAULT 'Misamis Oriental',
  `postal_code` VARCHAR(10) NOT NULL DEFAULT '9000',
  `emergency_contact_name` VARCHAR(150) NULL,
  `emergency_contact_phone` VARCHAR(20) NULL,
  `notes` TEXT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_staff_user` FOREIGN KEY (`user_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Customer Delivery Addresses (Supports Location Pinning & Full Address Structure)
CREATE TABLE `customer_addresses` (
  `address_id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NOT NULL,
  `address_label` VARCHAR(50) NOT NULL DEFAULT 'Home', -- e.g., 'Home', 'Office', 'Condo'
  `house_building_no` VARCHAR(100) NULL,
  `street_address` TEXT NOT NULL,
  `barangay` VARCHAR(100) NOT NULL DEFAULT 'Nazareth',
  `city_municipality` VARCHAR(100) NOT NULL DEFAULT 'Cagayan de Oro City',
  `province` VARCHAR(100) NOT NULL DEFAULT 'Misamis Oriental',
  `postal_code` VARCHAR(10) NOT NULL DEFAULT '9000',
  `landmark` VARCHAR(150) NULL,
  `latitude` DECIMAL(10,8) NOT NULL,
  `longitude` DECIMAL(11,8) NOT NULL,
  `is_default` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_addr_customer` FOREIGN KEY (`customer_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 2. DINE-IN TABLE MANAGEMENT & LIVE QUEUING MODULE
-- ============================================================================

CREATE TABLE `agape_tables` (
  `table_id` INT AUTO_INCREMENT PRIMARY KEY,
  `table_number` VARCHAR(20) NOT NULL UNIQUE,
  `seating_capacity` INT NOT NULL DEFAULT 2,
  `table_location_zone` VARCHAR(100) NOT NULL DEFAULT 'Indoor Main Dining',
  `status` ENUM('Available', 'Occupied', 'Reserved', 'Needs Cleaning') NOT NULL DEFAULT 'Available',
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `table_reservations` (
  `reservation_id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NOT NULL,
  `table_id` INT NOT NULL,
  `frontdesk_staff_id` INT NULL,
  `reservation_time` DATETIME NOT NULL,
  `party_size` INT NOT NULL DEFAULT 1,
  `status` ENUM('Pending', 'Confirmed', 'Checked_In', 'Cancelled', 'Completed') NOT NULL DEFAULT 'Pending',
  `special_notes` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_res_customer` FOREIGN KEY (`customer_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_res_table` FOREIGN KEY (`table_id`) REFERENCES `agape_tables` (`table_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_res_staff` FOREIGN KEY (`frontdesk_staff_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `live_queues` (
  `queue_id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NULL,
  `frontdesk_staff_id` INT NULL,
  `queue_number` VARCHAR(20) NOT NULL,
  `party_size` INT NOT NULL DEFAULT 1,
  `status` ENUM('Waiting', 'Called', 'Seated', 'Cancelled') NOT NULL DEFAULT 'Waiting',
  `called_at` DATETIME NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_queue_customer` FOREIGN KEY (`customer_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_queue_staff` FOREIGN KEY (`frontdesk_staff_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 3. MENU, INVENTORY & PROCUREMENT ("WHAT TO BUY") MODULE
-- ============================================================================

CREATE TABLE `menu_categories` (
  `category_id` INT AUTO_INCREMENT PRIMARY KEY,
  `category_name` VARCHAR(100) NOT NULL UNIQUE,
  `description` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `menu_items` (
  `item_id` INT AUTO_INCREMENT PRIMARY KEY,
  `category_id` INT NOT NULL,
  `item_name` VARCHAR(150) NOT NULL,
  `description` TEXT NULL,
  `price` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `is_available` TINYINT(1) DEFAULT 1,
  `image_url` VARCHAR(255) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_menu_category` FOREIGN KEY (`category_id`) REFERENCES `menu_categories` (`category_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `inventory_categories` (
  `inv_category_id` INT AUTO_INCREMENT PRIMARY KEY,
  `category_name` VARCHAR(100) NOT NULL UNIQUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `ingredient_inventories` (
  `ingredient_id` INT AUTO_INCREMENT PRIMARY KEY,
  `inv_category_id` INT NOT NULL,
  `ingredient_name` VARCHAR(150) NOT NULL,
  `current_stock` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `unit_of_measure` VARCHAR(20) NOT NULL,
  `minimum_reorder_level` DECIMAL(10,2) NOT NULL DEFAULT 10.00,
  `cost_per_unit` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `supplier_name` VARCHAR(150) NULL,
  `supplier_address` TEXT NULL, -- Detailed supplier address
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_inv_cat` FOREIGN KEY (`inv_category_id`) REFERENCES `inventory_categories` (`inv_category_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `recipe_ingredients` (
  `recipe_id` INT AUTO_INCREMENT PRIMARY KEY,
  `item_id` INT NOT NULL,
  `ingredient_id` INT NOT NULL,
  `quantity_required` DECIMAL(10,2) NOT NULL,
  CONSTRAINT `fk_recipe_item` FOREIGN KEY (`item_id`) REFERENCES `menu_items` (`item_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_recipe_ingredient` FOREIGN KEY (`ingredient_id`) REFERENCES `ingredient_inventories` (`ingredient_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 4. ORDERING, POS DOCUMENTATION & PAYMENTS MODULE
-- ============================================================================

CREATE TABLE `food_orders` (
  `order_id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NULL,
  `assigned_rider_id` INT NULL,
  `managed_by_id` INT NULL,
  `order_type` ENUM('Dine-In', 'Takeout', 'Delivery') NOT NULL,
  `order_status` ENUM('Pending_Payment', 'Preparing', 'Ready_For_Pickup', 'Out_For_Delivery', 'Completed', 'Cancelled') NOT NULL DEFAULT 'Pending_Payment',
  `payment_type` ENUM('Cash', 'GCash_QR', 'Maya_QR') NOT NULL DEFAULT 'Cash',
  `payment_status` ENUM('Unpaid', 'Verified', 'Refunded') NOT NULL DEFAULT 'Unpaid',
  `payment_receipt_url` VARCHAR(255) NULL,
  `delivery_address_id` INT NULL,
  `delivery_address_snapshot` TEXT NULL, -- Frozen address text snapshot at time of checkout
  `subtotal` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `delivery_fee` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `total_amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_order_customer` FOREIGN KEY (`customer_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_order_rider` FOREIGN KEY (`assigned_rider_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_order_manager` FOREIGN KEY (`managed_by_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_order_addr` FOREIGN KEY (`delivery_address_id`) REFERENCES `customer_addresses` (`address_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `order_items` (
  `order_item_id` INT AUTO_INCREMENT PRIMARY KEY,
  `order_id` INT NOT NULL,
  `item_id` INT NOT NULL,
  `quantity` INT NOT NULL DEFAULT 1,
  `unit_price` DECIMAL(10,2) NOT NULL,
  `subtotal` DECIMAL(10,2) NOT NULL,
  `special_instructions` VARCHAR(255) NULL,
  CONSTRAINT `fk_items_order` FOREIGN KEY (`order_id`) REFERENCES `food_orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_items_menu` FOREIGN KEY (`item_id`) REFERENCES `menu_items` (`item_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `pos_documentation_logs` (
  `pos_log_id` INT AUTO_INCREMENT PRIMARY KEY,
  `order_id` INT NOT NULL UNIQUE,
  `frontdesk_staff_id` INT NOT NULL,
  `terminal_type` ENUM('Web_POS', 'Mobile_Tablet_POS') NOT NULL,
  `cash_received` DECIMAL(10,2) DEFAULT 0.00,
  `change_given` DECIMAL(10,2) DEFAULT 0.00,
  `logged_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_pos_order` FOREIGN KEY (`order_id`) REFERENCES `food_orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pos_staff` FOREIGN KEY (`frontdesk_staff_id`) REFERENCES `system_users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 5. LIVE GPS RIDER TRACKING & MAP NAVIGATION MODULE
-- ============================================================================

CREATE TABLE `rider_locations` (
  `location_id` INT AUTO_INCREMENT PRIMARY KEY,
  `rider_id` INT NOT NULL,
  `order_id` INT NOT NULL,
  `current_latitude` DECIMAL(10,8) NOT NULL,
  `current_longitude` DECIMAL(11,8) NOT NULL,
  `heading_degree` DECIMAL(5,2) NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_loc_rider` FOREIGN KEY (`rider_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_loc_order` FOREIGN KEY (`order_id`) REFERENCES `food_orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 6. MULTI-ROLE LIVE CHAT SUPPORT MODULE
-- ============================================================================

CREATE TABLE `chat_conversations` (
  `conversation_id` INT AUTO_INCREMENT PRIMARY KEY,
  `customer_id` INT NOT NULL,
  `assigned_staff_id` INT NULL,
  `order_id` INT NULL,
  `status` ENUM('Open', 'Resolved', 'Closed') DEFAULT 'Open',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_chat_cust` FOREIGN KEY (`customer_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_chat_staff` FOREIGN KEY (`assigned_staff_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_chat_order` FOREIGN KEY (`order_id`) REFERENCES `food_orders` (`order_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `chat_messages` (
  `message_id` INT AUTO_INCREMENT PRIMARY KEY,
  `conversation_id` INT NOT NULL,
  `sender_id` INT NOT NULL,
  `message_body` TEXT NOT NULL,
  `is_read` TINYINT(1) DEFAULT 0,
  `sent_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_msg_conv` FOREIGN KEY (`conversation_id`) REFERENCES `chat_conversations` (`conversation_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_msg_sender` FOREIGN KEY (`sender_id`) REFERENCES `system_users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 7. SYSTEM MUST-HAVES: ARCHIVING & SECURITY AUDIT TRAILS MODULE
-- ============================================================================

CREATE TABLE `archived_records` (
  `archive_id` INT AUTO_INCREMENT PRIMARY KEY,
  `archived_by_id` INT NOT NULL,
  `entity_type` VARCHAR(50) NOT NULL,
  `entity_id` INT NOT NULL,
  `record_payload` JSON NOT NULL,
  `archived_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_archive_user` FOREIGN KEY (`archived_by_id`) REFERENCES `system_users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `audit_trails` (
  `audit_id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NULL,
  `action_performed` VARCHAR(150) NOT NULL,
  `affected_table` VARCHAR(50) NOT NULL,
  `ip_address` VARCHAR(45) NULL,
  `user_agent` TEXT NULL,
  `performed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`) REFERENCES `system_users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 8. STORED PROCEDURES (ADD, EDIT, SOFT-DELETE OPERATIONS)
-- ============================================================================

DELIMITER $$

-- PROCEDURE 1: ADD NEW USER (USER MANAGEMENT)
CREATE PROCEDURE `sp_AddUser` (
  IN p_role_id INT,
  IN p_first_name VARCHAR(100),
  IN p_last_name VARCHAR(100),
  IN p_email VARCHAR(150),
  IN p_phone VARCHAR(20),
  IN p_password_hash VARCHAR(255)
)
BEGIN
  DECLARE new_user_id INT;
  
  INSERT INTO `system_users` (`role_id`, `first_name`, `last_name`, `email`, `phone_number`, `status`)
  VALUES (p_role_id, p_first_name, p_last_name, p_email, p_phone, 'Active');
  
  SET new_user_id = LAST_INSERT_ID();
  
  INSERT INTO `user_credentials` (`user_id`, `password_hash`)
  VALUES (new_user_id, p_password_hash);
  
  INSERT INTO `audit_trails` (`user_id`, `action_performed`, `affected_table`)
  VALUES (new_user_id, 'USER_ADDED', 'system_users');
END$$

-- PROCEDURE 2: EDIT USER DETAILS
CREATE PROCEDURE `sp_EditUser` (
  IN p_user_id INT,
  IN p_first_name VARCHAR(100),
  IN p_last_name VARCHAR(100),
  IN p_phone VARCHAR(20),
  IN p_status ENUM('Active', 'Inactive', 'Suspended', 'Archived')
)
BEGIN
  UPDATE `system_users`
  SET `first_name` = p_first_name,
      `last_name` = p_last_name,
      `phone_number` = p_phone,
      `status` = p_status
  WHERE `user_id` = p_user_id;
  
  INSERT INTO `audit_trails` (`user_id`, `action_performed`, `affected_table`)
  VALUES (p_user_id, 'USER_UPDATED', 'system_users');
END$$

-- PROCEDURE 3: SOFT-DELETE / ARCHIVE USER
CREATE PROCEDURE `sp_SoftDeleteUser` (
  IN p_user_id INT,
  IN p_archived_by INT
)
BEGIN
  -- Mark status as Archived
  UPDATE `system_users` SET `status` = 'Archived' WHERE `user_id` = p_user_id;
  
  -- Record to Archive Table
  INSERT INTO `archived_records` (`archived_by_id`, `entity_type`, `entity_id`, `record_payload`)
  SELECT p_archived_by, 'system_users', p_user_id, JSON_OBJECT('user_id', user_id, 'email', email, 'first_name', first_name, 'last_name', last_name)
  FROM `system_users` WHERE `user_id` = p_user_id;
  
  INSERT INTO `audit_trails` (`user_id`, `action_performed`, `affected_table`)
  VALUES (p_archived_by, 'USER_SOFT_DELETED', 'system_users');
END$$

-- PROCEDURE 4: ADD MENU ITEM
CREATE PROCEDURE `sp_AddMenuItem` (
  IN p_category_id INT,
  IN p_item_name VARCHAR(150),
  IN p_description TEXT,
  IN p_price DECIMAL(10,2),
  IN p_image_url VARCHAR(255)
)
BEGIN
  INSERT INTO `menu_items` (`category_id`, `item_name`, `description`, `price`, `image_url`)
  VALUES (p_category_id, p_item_name, p_description, p_price, p_image_url);
END$$

-- PROCEDURE 5: EDIT MENU ITEM
CREATE PROCEDURE `sp_EditMenuItem` (
  IN p_item_id INT,
  IN p_item_name VARCHAR(150),
  IN p_price DECIMAL(10,2),
  IN p_is_available TINYINT(1)
)
BEGIN
  UPDATE `menu_items`
  SET `item_name` = p_item_name,
      `price` = p_price,
      `is_available` = p_is_available
  WHERE `item_id` = p_item_id;
END$$

-- PROCEDURE 6: DELETE / ARCHIVE MENU ITEM
CREATE PROCEDURE `sp_SoftDeleteMenuItem` (
  IN p_item_id INT,
  IN p_archived_by INT
)
BEGIN
  -- Set unavailable
  UPDATE `menu_items` SET `is_available` = 0 WHERE `item_id` = p_item_id;
  
  -- Store Archive Snapshot
  INSERT INTO `archived_records` (`archived_by_id`, `entity_type`, `entity_id`, `record_payload`)
  SELECT p_archived_by, 'menu_items', p_item_id, JSON_OBJECT('item_id', item_id, 'item_name', item_name, 'price', price)
  FROM `menu_items` WHERE `item_id` = p_item_id;
END$$

DELIMITER ;

-- ============================================================================
-- INITIAL SEED DATA
-- ============================================================================

INSERT INTO `user_roles` (`role_id`, `role_name`, `description`) VALUES
(1, 'System Admin', 'Full system access, security audit trails, user management, global settings'),
(2, 'Store Manager', 'Inventory procurement, delivery dispatch overrides, sales reports, menu editing'),
(3, 'Frontdesk Staff', 'Web & Mobile POS order entry, table assignments, queue calling, customer chat support'),
(4, 'Kitchen Staff', 'Kitchen Display System (KDS) prep management and stock usage tracking'),
(5, 'Delivery Rider', 'Mobile GPS location pinning, turn-by-turn map navigation, and customer chat'),
(6, 'Customer', 'Online food ordering, QR payment uploads, live table availability, and rider tracking');

INSERT INTO `menu_categories` (`category_id`, `category_name`, `description`) VALUES
(1, 'Specialty Coffee', 'Espresso-based drinks, pour-overs, and cold brews'),
(2, 'Non-Coffee Drinks', 'Matcha, milk teas, fruit teas, and fresh juices'),
(3, 'Short Orders & Snacks', 'Sandwiches, waffles, fries, and appetizers'),
(4, 'Main Rice Meals', 'Beef, pork, chicken, and pasta dishes'),
(5, 'Desserts', 'Cakes, pastries, and ice cream');

INSERT INTO `inventory_categories` (`inv_category_id`, `category_name`) VALUES
(1, 'Coffee Beans & Roasts'),
(2, 'Dairy & Liquids'),
(3, 'Syrups & Flavorings'),
(4, 'Meat & Proteins'),
(5, 'Packaging & Disposable Goods');

INSERT INTO `agape_tables` (`table_number`, `seating_capacity`, `table_location_zone`, `status`) VALUES
('T-01', 2, 'Indoor Main Dining', 'Available'),
('T-02', 2, 'Indoor Main Dining', 'Available'),
('T-03', 4, 'Indoor Main Dining', 'Available'),
('T-04', 4, 'Al Fresco Terrace', 'Occupied'),
('T-05', 6, 'Al Fresco Terrace', 'Reserved'),
('T-06', 8, 'VIP Mezzanine', 'Needs Cleaning');

-- Create Default Admin User
CALL sp_AddUser(1, 'Admin', 'Agape', 'admin@agapecoffee.com', '09170000000', '2y10$YourHashedPasswordHere');

