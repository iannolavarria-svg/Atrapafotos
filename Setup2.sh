#!/bin/bash
# create_content_full.sh
# Genera todo el contenido del plugin StaffPlugin (clases, pom, plugin.yml, workflow)
set -e

PROJECT="StaffPlugin"
PKG="com.iann.staff"
PKG_DIR="${PROJECT}/src/main/java/${PKG//./\/}"
RES_DIR="${PROJECT}/src/main/resources"
WORKFLOW_DIR="${PROJECT}/.github/workflows"

if [ ! -d "${PKG_DIR}" ]; then
  echo "Estructura base no encontrada. Ejecuta create_structure_full.sh primero o crea la estructura del repo."
  exit 1
fi

# ---------------------------
# pom.xml
# ---------------------------
cat > "${PROJECT}/pom.xml" <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                             http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.iann.staff</groupId>
    <artifactId>StaffPlugin</artifactId>
    <version>2.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
    </properties>

    <repositories>
        <repository>
            <id>papermc</id>
            <url>https://repo.papermc.io/repository/maven-public/</url>
        </repository>
    </repositories>

    <dependencies>
        <dependency>
            <groupId>io.papermc.paper</groupId>
            <artifactId>paper-api</artifactId>
            <version>1.21.9-R0.1-SNAPSHOT</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>
EOF

# ---------------------------
# plugin.yml
# ---------------------------
cat > "${RES_DIR}/plugin.yml" <<'EOF'
name: StaffPlugin
main: com.iann.staff.Main
version: 2.0.0
api-version: 1.21
author: Iann
commands:
  staff:
    description: Activa el modo staff (items)
    usage: /staff
  unstaff:
    description: Desactiva el modo staff
    usage: /unstaff
  staffchat:
    description: Mensaje al chat de staff
  devmode:
    description: Modo desarrollador
permissions:
  staffplugin.use:
    default: op
  staffplugin.dev:
    default: op
EOF

# ---------------------------
# GitHub Actions workflow
# ---------------------------
mkdir -p "${WORKFLOW_DIR}"
cat > "${WORKFLOW_DIR}/build.yml" <<'EOF'
name: Build Paper Plugin

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout repository
      uses: actions/checkout@v3

    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'

    - name: Build with Maven
      run: mvn -B -DskipTests clean package

    - name: Upload JAR
      uses: actions/upload-artifact@v3
      with:
        name: StaffPlugin-JAR
        path: target/*.jar
EOF

# ---------------------------
# build.sh (opcional local)
# ---------------------------
cat > "${PROJECT}/build.sh" <<'EOF'
#!/bin/bash
mvn -B -DskipTests clean package
EOF
chmod +x "${PROJECT}/build.sh"

# ---------------------------
# Main.java
# ---------------------------
cat > "${PKG_DIR}/Main.java" <<'EOF'
package ${PKG};

import org.bukkit.plugin.java.JavaPlugin;
import ${PKG}.managers.*;
import ${PKG}.listeners.*;

public class Main extends JavaPlugin {

    public StaffManager staffManager;
    public BanManager banManager;
    public FreezeManager freezeManager;
    public DecoyManager decoyManager;
    public TPManager tpManager;
    public MenuManager menuManager;

    @Override
    public void onEnable() {
        saveDefaultConfig();

        this.banManager = new BanManager(this);
        this.freezeManager = new FreezeManager(this);
        this.decoyManager = new DecoyManager(this);
        this.tpManager = new TPManager(this);
        this.staffManager = new StaffManager(this);
        this.menuManager = new MenuManager(this);

        getCommand("staff").setExecutor(new ${PKG}.commands.StaffCommand(this));
        getCommand("unstaff").setExecutor(new ${PKG}.commands.UnstaffCommand(this));
        getCommand("staffchat").setExecutor(new ${PKG}.commands.StaffChatCommand(this));
        getCommand("devmode").setExecutor(new ${PKG}.commands.DevModeCommand(this));

        getServer().getPluginManager().registerEvents(new ${PKG}.listeners.StaffListener(this), this);

        getLogger().info("StaffPlugin v2 habilitado.");
    }

    @Override
    public void onDisable() {
        getLogger().info("StaffPlugin v2 deshabilitado.");
    }
}
EOF

# ---------------------------
# Helpers
# ---------------------------
cat > "${PKG_DIR}/managers/Helpers.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.Material;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import java.util.List;
import java.util.ArrayList;

public class Helpers {

    public static ItemStack createItem(Material mat, String name, List<String> lore) {
        ItemStack it = new ItemStack(mat);
        ItemMeta meta = it.getItemMeta();
        if (meta != null) {
            if (name != null) meta.setDisplayName(name);
            if (lore != null) meta.setLore(lore);
            it.setItemMeta(meta);
        }
        return it;
    }

    public static ItemStack createItem(Material mat, String name) {
        return createItem(mat, name, null);
    }

    public static List<String> lore(String... lines) {
        List<String> l = new ArrayList<>();
        for (String s : lines) l.add(s);
        return l;
    }
}
EOF

# ---------------------------
# StaffManager
# ---------------------------
cat > "${PKG_DIR}/managers/StaffManager.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.entity.Player;
import org.bukkit.GameMode;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.PlayerInventory;
import org.bukkit.Material;
import org.bukkit.ChatColor;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import ${PKG}.Main;

public class StaffManager {

    private final Main plugin;
    private final Map<UUID, ItemStack[]> savedInv = new HashMap<>();
    private final Map<UUID, ItemStack[]> savedArmor = new HashMap<>();
    private final Map<UUID, GameMode> savedGM = new HashMap<>();

    public StaffManager(Main plugin) {
        this.plugin = plugin;
    }

    public boolean isStaff(Player p) {
        return savedInv.containsKey(p.getUniqueId());
    }

    public void enableStaff(Player p) {
        if (isStaff(p)) return;
        UUID id = p.getUniqueId();
        PlayerInventory inv = p.getInventory();
        savedInv.put(id, inv.getContents());
        savedArmor.put(id, inv.getArmorContents());
        savedGM.put(id, p.getGameMode());

        inv.clear();
        inv.setArmorContents(new ItemStack[4]);

        Material ban = Material.valueOf(plugin.getConfig().getString("items.banhammer","NETHERITE_AXE"));
        Material inspect = Material.valueOf(plugin.getConfig().getString("items.inspectrod","BLAZE_ROD"));
        Material compass = Material.valueOf(plugin.getConfig().getString("items.compass","COMPASS"));
        Material noclip = Material.valueOf(plugin.getConfig().getString("items.noclip","FEATHER"));
        Material decoy = Material.valueOf(plugin.getConfig().getString("items.decoy","NETHER_STAR"));
        Material vanish = Material.valueOf(plugin.getConfig().getString("items.vanish","TOTEM_OF_UNDYING"));
        Material warntool = Material.valueOf(plugin.getConfig().getString("items.warntool","IRON_SWORD"));
        Material staffmenu = Material.valueOf(plugin.getConfig().getString("items.staffmenu","WRITTEN_BOOK"));
        Material trollmenu = Material.valueOf(plugin.getConfig().getString("items.trollmenu","BLAZE_POWDER"));

        inv.addItem(Helpers.createItem(ban, ChatColor.RED + "Ban Hammer"));
        inv.addItem(Helpers.createItem(inspect, ChatColor.YELLOW + "Inspect Rod"));
        inv.addItem(Helpers.createItem(noclip, ChatColor.AQUA + "Noclip Toggle"));
        inv.addItem(Helpers.createItem(compass, ChatColor.GREEN + "TP Compass"));
        inv.addItem(Helpers.createItem(decoy, ChatColor.LIGHT_PURPLE + "Decoy Star"));
        inv.addItem(Helpers.createItem(vanish, ChatColor.GRAY + "Vanish Totem"));
        inv.addItem(Helpers.createItem(warntool, ChatColor.GOLD + "Warn Sword"));
        inv.addItem(Helpers.createItem(staffmenu, ChatColor.DARK_BLUE + "Staff Menu"));
        inv.addItem(Helpers.createItem(trollmenu, ChatColor.DARK_RED + "Troll Menu"));

        p.setGameMode(GameMode.CREATIVE);
        p.setAllowFlight(true);
        p.setFlying(true);

        p.sendTitle(ChatColor.GREEN + "STAFF MODE", ChatColor.GRAY + "Herramientas entregadas", 5, 40, 5);
        p.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + plugin.getConfig().getString("messages.staff_enabled","Modo staff activado."));
    }

    public void disableStaff(Player p) {
        if (!isStaff(p)) return;
        UUID id = p.getUniqueId();
        ItemStack[] inv = savedInv.get(id);
        ItemStack[] armor = savedArmor.get(id);
        GameMode gm = savedGM.getOrDefault(id, GameMode.SURVIVAL);

        p.getInventory().clear();
        if (inv != null) p.getInventory().setContents(inv);
        if (armor != null) p.getInventory().setArmorContents(armor);

        p.setGameMode(gm);
        p.setAllowFlight(false);
        p.setFlying(false);

        savedInv.remove(id);
        savedArmor.remove(id);
        savedGM.remove(id);

        p.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + plugin.getConfig().getString("messages.staff_disabled","Modo staff desactivado."));
    }
}
EOF

# ---------------------------
# BanManager
# ---------------------------
cat > "${PKG_DIR}/managers/BanManager.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import ${PKG}.Main;

import java.io.File;
import java.io.IOException;
import java.util.Map;
import java.util.HashMap;
import java.util.Set;
import java.util.HashSet;
import java.util.UUID;

public class BanManager {

    private final Main plugin;
    private final File file;
    private final FileConfiguration cfg;

    public final Map<UUID, UUID> pendingBan = new HashMap<>();

    public BanManager(Main plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "bans.yml");
        if (!file.exists()) {
            try { plugin.getDataFolder().mkdirs(); file.createNewFile(); } catch (IOException e) { e.printStackTrace(); }
        }
        this.cfg = YamlConfiguration.loadConfiguration(file);
    }

    public void banPlayer(UUID target, String banner, String reason, long expiryMillis) {
        String k = target.toString();
        cfg.set(k + ".banner", banner);
        cfg.set(k + ".reason", reason);
        cfg.set(k + ".expiry", expiryMillis);
        save();

        OfflinePlayer op = Bukkit.getOfflinePlayer(target);
        if (op.isOnline()) {
            op.getPlayer().kickPlayer("Has sido baneado: " + reason);
        }

        if (plugin.getConfig().getBoolean("features.log_actions", true)) {
            plugin.getLogger().info("[StaffPlugin] Jugador " + target + " baneado por " + banner + " (" + reason + ")");
        }
    }

    public boolean isBanned(UUID target) {
        String k = target.toString();
        if (!cfg.contains(k + ".expiry")) return false;
        long exp = cfg.getLong(k + ".expiry", -1L);
        if (exp == -1L) return true;
        if (System.currentTimeMillis() > exp) {
            cfg.set(k, null);
            save();
            return false;
        }
        return true;
    }

    public void unban(UUID target) {
        cfg.set(target.toString(), null);
        save();
    }

    public Set<UUID> listBans() {
        Set<UUID> out = new HashSet<>();
        for (String k : cfg.getKeys(false)) {
            try { out.add(UUID.fromString(k)); } catch (Exception ignored) {}
        }
        return out;
    }

    private void save() {
        try { cfg.save(file); } catch (IOException e) { e.printStackTrace(); }
    }

    public static long presetToMillis(String preset) {
        if (preset == null) return -1L;
        if (preset.equalsIgnoreCase("perma")) return -1L;
        try {
            preset = preset.toLowerCase();
            if (preset.endsWith("m")) return Long.parseLong(preset.substring(0, preset.length()-1)) * 60_000L;
            if (preset.endsWith("h")) return Long.parseLong(preset.substring(0, preset.length()-1)) * 3_600_000L;
            if (preset.endsWith("d")) return Long.parseLong(preset.substring(0, preset.length()-1)) * 86_400_000L;
        } catch (Exception ex) { return -1L; }
        return -1L;
    }
}
EOF

# ---------------------------
# FreezeManager
# ---------------------------
cat > "${PKG_DIR}/managers/FreezeManager.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.entity.Player;
import org.bukkit.Bukkit;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerMoveEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.EventHandler;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;

import ${PKG}.Main;

import java.util.Set;
import java.util.HashSet;
import java.util.UUID;

public class FreezeManager implements Listener {
    private final ${PKG}.Main plugin;
    private final Set<UUID> frozen = new HashSet<>();

    public FreezeManager(${PKG}.Main plugin) {
        this.plugin = plugin;
        plugin.getServer().getPluginManager().registerEvents(this, plugin);
    }

    public void freeze(Player p) {
        frozen.add(p.getUniqueId());
        p.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + plugin.getConfig().getString("messages.frozen","Estás congelado, sigue las indicaciones."));
        p.addPotionEffect(new PotionEffect(PotionEffectType.SLOW, 9999999, 10, false, false, false));
        if (plugin.getConfig().getBoolean("effects.freeze_particles", true)) {
            p.getWorld().spawnParticle(Particle.SNOW_SHOVEL, p.getLocation(), 20, 0.5, 1, 0.5);
        }
        if (plugin.getConfig().getBoolean("effects.freeze_sound", true)) {
            p.getWorld().playSound(p.getLocation(), Sound.BLOCK_ANVIL_LAND, 1f, 1f);
        }
    }

    public void unfreeze(Player p) {
        frozen.remove(p.getUniqueId());
        p.removePotionEffect(PotionEffectType.SLOW);
        p.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + plugin.getConfig().getString("messages.unfreeze","Has sido descongelado."));
    }

    public boolean isFrozen(Player p) {
        return frozen.contains(p.getUniqueId());
    }

    @EventHandler
    public void onMove(PlayerMoveEvent e) {
        if (frozen.contains(e.getPlayer().getUniqueId())) {
            if (!e.getFrom().getBlock().equals(e.getTo().getBlock())) {
                e.setTo(e.getFrom());
            }
        }
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        frozen.remove(e.getPlayer().getUniqueId());
    }

    @EventHandler
    public void onCommand(PlayerCommandPreprocessEvent e) {
        if (frozen.contains(e.getPlayer().getUniqueId())) {
            e.getPlayer().sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "No puedes usar comandos mientras estás congelado.");
            e.setCancelled(true);
        }
    }
}
EOF

# ---------------------------
# DecoyManager
# ---------------------------
cat > "${PKG_DIR}/managers/DecoyManager.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.EntityType;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.entity.Player;
import org.bukkit.inventory.meta.SkullMeta;
import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;

import ${PKG}.Main;

import java.util.Set;
import java.util.HashSet;

public class DecoyManager {
    private final Main plugin;
    private final Set<ArmorStand> decoys = new HashSet<>();

    public DecoyManager(Main plugin) {
        this.plugin = plugin;
    }

    public ArmorStand spawnDecoy(Location loc, Player owner) {
        World w = loc.getWorld();
        if (w == null) return null;
        ArmorStand as = (ArmorStand) w.spawnEntity(loc, EntityType.ARMOR_STAND);
        as.setCustomName(owner.getName() + "_decoy");
        as.setCustomNameVisible(true);
        as.setInvulnerable(true);
        as.setGravity(false);

        ItemStack head = new ItemStack(Material.PLAYER_HEAD);
        SkullMeta meta = (SkullMeta) head.getItemMeta();
        if (meta != null) {
            OfflinePlayer op = Bukkit.getOfflinePlayer(owner.getUniqueId());
            try { meta.setOwningPlayer(op); } catch (Exception ignored) {}
            head.setItemMeta(meta);
            as.getEquipment().setHelmet(head);
        }

        as.getEquipment().setChestplate(new ItemStack(Material.IRON_CHESTPLATE));
        as.getEquipment().setLeggings(new ItemStack(Material.IRON_LEGGINGS));
        as.getEquipment().setBoots(new ItemStack(Material.IRON_BOOTS));

        decoys.add(as);

        new BukkitRunnable() {
            @Override
            public void run() {
                if (as.isDead() || !decoys.contains(as)) { cancel(); return; }
                try {
                    as.teleport(as.getLocation().add((Math.random()-0.5)*0.8, 0, (Math.random()-0.5)*0.8));
                } catch (Exception ignored) {}
            }
        }.runTaskTimer(plugin, 40L, 120L);

        return as;
    }

    public void removeDecoy(ArmorStand as) {
        decoys.remove(as);
        if (!as.isDead()) as.remove();
    }

    public boolean isDecoy(ArmorStand as) { return decoys.contains(as); }
}
EOF

# ---------------------------
# TPManager
# ---------------------------
cat > "${PKG_DIR}/managers/TPManager.java" <<'EOF'
package ${PKG}.managers;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.inventory.meta.SkullMeta;
import org.bukkit.inventory.meta.ItemMeta;

import ${PKG}.Main;

public class TPManager {

    private final Main plugin;

    public TPManager(Main plugin) { this.plugin = plugin; }

    public void openTPMenu(Player staff) {
        Inventory inv = Bukkit.createInventory(null, 9*3, "TP Menu");
        for (Player p : Bukkit.getOnlinePlayers()) {
            if (p.equals(staff)) continue;
            ItemStack head = new ItemStack(Material.PLAYER_HEAD);
            SkullMeta meta = (SkullMeta) head.getItemMeta();
            if (meta != null) {
                meta.setDisplayName(p.getName());
                try { meta.setOwningPlayer(p); } catch (Exception ignored) {}
                head.setItemMeta(meta);
                inv.addItem(head);
            }
        }
        staff.openInventory(inv);
    }

    public Player getPlayerFromItem(ItemStack item) {
        if (item == null) return null;
        if (item.getType() != Material.PLAYER_HEAD) return null;
        ItemMeta meta = item.getItemMeta();
        if (meta == null || meta.getDisplayName() == null) return null;
        return Bukkit.getPlayerExact(meta.getDisplayName());
    }
}
EOF

# ---------------------------
# MenuManager + Menus
# ---------------------------
cat > "${PKG_DIR}/managers/MenuManager.java" <<'EOF'
package ${PKG}.managers;

import ${PKG}.Main;
import org.bukkit.entity.Player;

public class MenuManager {
    private final Main plugin;
    public final com.iann.staff.menus.BanMenu banMenu;
    public final com.iann.staff.menus.WarnMenu warnMenu;
    public final com.iann.staff.menus.TrollMenu trollMenu;

    public MenuManager(Main plugin) {
        this.plugin = plugin;
        this.banMenu = new com.iann.staff.menus.BanMenu(plugin);
        this.warnMenu = new com.iann.staff.menus.WarnMenu(plugin);
        this.trollMenu = new com.iann.staff.menus.TrollMenu(plugin);
    }

    public void openBan(Player staff, Player target) { banMenu.open(staff, target); }
    public void openWarn(Player staff, Player target) { warnMenu.open(staff, target); }
    public void openTroll(Player staff, Player target) { trollMenu.open(staff, target); }
}
EOF

cat > "${PKG_DIR}/menus/BanMenu.java" <<'EOF'
package ${PKG}.menus;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.inventory.meta.ItemMeta;
import com.iann.staff.Main;

import java.util.List;
import java.util.ArrayList;

public class BanMenu {

    private final Main plugin;

    public BanMenu(Main plugin) { this.plugin = plugin; }

    public void open(Player staff, Player target) {
        Inventory inv = Bukkit.createInventory(null, 9, "Ban Menu");
        addPreset(inv, "10m");
        addPreset(inv, "1h");
        addPreset(inv, "1d");
        addPreset(inv, "7d");
        addPreset(inv, "perma");
        staff.openInventory(inv);
        plugin.banManager.pendingBan.put(staff.getUniqueId(), target.getUniqueId());
    }

    private void addPreset(Inventory inv, String preset) {
        ItemStack it = new ItemStack(Material.PAPER);
        ItemMeta meta = it.getItemMeta();
        if (meta != null) {
            meta.setDisplayName(preset);
            List<String> lore = new ArrayList<>();
            lore.add("Click para banear con duración " + preset);
            meta.setLore(lore);
            it.setItemMeta(meta);
        }
        inv.addItem(it);
    }
}
EOF

cat > "${PKG_DIR}/menus/WarnMenu.java" <<'EOF'
package ${PKG}.menus;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.inventory.meta.ItemMeta;
import com.iann.staff.Main;

import java.util.ArrayList;
import java.util.List;

public class WarnMenu {

    private final Main plugin;

    public WarnMenu(Main plugin) { this.plugin = plugin; }

    public void open(Player staff, Player target) {
        Inventory inv = Bukkit.createInventory(null, 9, "Warn Menu");
        addPreset(inv, "Advertencia leve");
        addPreset(inv, "Advertencia media");
        addPreset(inv, "Advertencia grave");
        staff.openInventory(inv);
    }

    private void addPreset(Inventory inv, String preset) {
        ItemStack it = new ItemStack(Material.PAPER);
        ItemMeta meta = it.getItemMeta();
        if (meta != null) {
            meta.setDisplayName(preset);
            List<String> lore = new ArrayList<>();
            lore.add("Click para enviar: " + preset);
            meta.setLore(lore);
            it.setItemMeta(meta);
        }
        inv.addItem(it);
    }
}
EOF

cat > "${PKG_DIR}/menus/TrollMenu.java" <<'EOF'
package ${PKG}.menus;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.inventory.meta.ItemMeta;
import com.iann.staff.Main;

import java.util.ArrayList;
import java.util.List;

public class TrollMenu {

    private final Main plugin;

    public TrollMenu(Main plugin) { this.plugin = plugin; }

    public void open(Player staff, Player target) {
        Inventory inv = Bukkit.createInventory(null, 9, "Troll Menu");
        addTrollItem(inv, Material.SNOWBALL, "Lanzar Bola");
        addTrollItem(inv, Material.FIRE_CHARGE, "Fuego");
        addTrollItem(inv, Material.ENDER_PEARL, "Teletransportar");
        addTrollItem(inv, Material.LEAD, "Atar");
        staff.openInventory(inv);
    }

    private void addTrollItem(Inventory inv, Material mat, String name) {
        ItemStack it = new ItemStack(mat);
        ItemMeta meta = it.getItemMeta();
        if (meta != null) {
            meta.setDisplayName(name);
            java.util.List<String> lore = new java.util.ArrayList<>();
            lore.add("Click para ejecutar acción: " + name);
            meta.setLore(lore);
            it.setItemMeta(meta);
        }
        inv.addItem(it);
    }
}
EOF

# ---------------------------
# Commands
# ---------------------------
cat > "${PKG_DIR}/commands/StaffCommand.java" <<'EOF'
package ${PKG}.commands;

import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import ${PKG}.Main;

public class StaffCommand implements CommandExecutor {

    private final Main plugin;

    public StaffCommand(Main plugin) { this.plugin = plugin; }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) return true;
        Player p = (Player) sender;
        plugin.staffManager.enableStaff(p);
        return true;
    }
}
EOF

cat > "${PKG_DIR}/commands/UnstaffCommand.java" <<'EOF'
package ${PKG}.commands;

import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import ${PKG}.Main;

public class UnstaffCommand implements CommandExecutor {

    private final Main plugin;

    public UnstaffCommand(Main plugin) { this.plugin = plugin; }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) return true;
        Player p = (Player) sender;
        plugin.staffManager.disableStaff(p);
        return true;
    }
}
EOF

cat > "${PKG_DIR}/commands/StaffChatCommand.java" <<'EOF'
package ${PKG}.commands;

import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.Bukkit;
import ${PKG}.Main;

public class StaffChatCommand implements CommandExecutor {

    private final Main plugin;

    public StaffChatCommand(Main plugin) { this.plugin = plugin; }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) return true;
        Player p = (Player) sender;
        if (args.length == 0) {
            p.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Uso: /staffchat <mensaje>");
            return true;
        }
        String msg = String.join(" ", args);
        for (Player pl : Bukkit.getOnlinePlayers()) {
            if (plugin.staffManager.isStaff(pl)) {
                pl.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "[Staff] " + p.getName() + ": " + msg);
            }
        }
        return true;
    }
}
EOF

cat > "${PKG_DIR}/commands/DevModeCommand.java" <<'EOF'
package ${PKG}.commands;

import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import ${PKG}.Main;

public class DevModeCommand implements CommandExecutor {

    private final Main plugin;

    public DevModeCommand(Main plugin) { this.plugin = plugin; }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) return true;
        Player p = (Player) sender;
        if (!p.hasPermission("staffplugin.dev")) {
            p.sendMessage("No tienes permiso.");
            return true;
        }
        p.getInventory().addItem(new ItemStack(Material.NETHERITE_AXE));
        p.getInventory().addItem(new ItemStack(Material.BLAZE_ROD));
        p.getInventory().addItem(new ItemStack(Material.NETHER_STAR));
        p.sendMessage("DevMode: herramientas entregadas.");
        return true;
    }
}
EOF

# ---------------------------
# Listener (manejo de items y menús)
# ---------------------------
cat > "${PKG_DIR}/listeners/StaffListener.java" <<'EOF'
package ${PKG}.listeners;

import ${PKG}.Main;
import ${PKG}.managers.*;
import ${PKG}.menus.*;
import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.entity.ArmorStand;
import org.bukkit.event.Listener;
import org.bukkit.event.EventHandler;
import org.bukkit.event.player.PlayerInteractEntityEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.block.Action;
import org.bukkit.inventory.ItemStack;
import org.bukkit.Material;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.meta.ItemMeta;

import java.util.UUID;

public class StaffListener implements Listener {

    private final Main plugin;

    public StaffListener(Main plugin) {
        this.plugin = plugin;
        plugin.getServer().getPluginManager().registerEvents(this, plugin);
    }

    @EventHandler
    public void onPlayerInteractEntity(PlayerInteractEntityEvent e) {
        Player staff = e.getPlayer();
        if (!plugin.staffManager.isStaff(staff)) return;
        ItemStack hand = staff.getInventory().getItemInMainHand();
        if (hand == null) return;
        Material mat = hand.getType();

        if (mat == Material.valueOf(plugin.getConfig().getString("items.banhammer","NETHERITE_AXE"))) {
            if (e.getRightClicked() instanceof Player target) {
                plugin.menuManager.openBan(staff, target);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "BanMenu abierto para " + target.getName());
                e.setCancelled(true);
            } else if (e.getRightClicked() instanceof ArmorStand as) {
                plugin.decoyManager.removeDecoy(as);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Señuelo eliminado.");
                e.setCancelled(true);
            }
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.inspectrod","BLAZE_ROD"))) {
            if (e.getRightClicked() instanceof Player target) {
                staff.openInventory(target.getInventory());
                plugin.freezeManager.freeze(target);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Jugador inspeccionado y congelado: " + target.getName());
                e.setCancelled(true);
            } else if (e.getRightClicked() instanceof ArmorStand as) {
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Señuelo inspeccionado.");
                e.setCancelled(true);
            }
            return;
        }
    }

    @EventHandler
    public void onPlayerInteract(PlayerInteractEvent e) {
        Player staff = e.getPlayer();
        if (!plugin.staffManager.isStaff(staff)) return;
        Action action = e.getAction();
        if (!(action == Action.RIGHT_CLICK_AIR || action == Action.RIGHT_CLICK_BLOCK)) return;
        ItemStack hand = staff.getInventory().getItemInMainHand();
        if (hand == null) return;
        Material mat = hand.getType();

        if (mat == Material.valueOf(plugin.getConfig().getString("items.noclip","FEATHER"))) {
            if (staff.getGameMode().name().equals("SPECTATOR")) {
                staff.setGameMode(org.bukkit.GameMode.CREATIVE);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Noclip desactivado.");
            } else {
                staff.setGameMode(org.bukkit.GameMode.SPECTATOR);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Noclip activado.");
            }
            e.setCancelled(true);
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.compass","COMPASS"))) {
            plugin.tpManager.openTPMenu(staff);
            e.setCancelled(true);
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.decoy","NETHER_STAR"))) {
            plugin.decoyManager.spawnDecoy(staff.getLocation(), staff);
            staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Señuelo spawneado.");
            e.setCancelled(true);
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.vanish","TOTEM_OF_UNDYING"))) {
            boolean nowHidden = toggleVanishFor(staff);
            staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + (nowHidden ? "Vanish activado." : "Vanish desactivado."));
            e.setCancelled(true);
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.staffmenu","WRITTEN_BOOK"))) {
            plugin.tpManager.openTPMenu(staff);
            e.setCancelled(true);
            return;
        }

        if (mat == Material.valueOf(plugin.getConfig().getString("items.trollmenu","BLAZE_POWDER"))) {
            plugin.menuManager.openTroll(staff, staff);
            e.setCancelled(true);
            return;
        }
    }

    private boolean toggleVanishFor(Player staff) {
        boolean currentlyHidden = false;
        for (Player p : Bukkit.getOnlinePlayers()) {
            if (p.equals(staff)) continue;
            if (!plugin.staffManager.isStaff(p) && !p.canSee(staff)) { currentlyHidden = true; break; }
        }
        if (!currentlyHidden) {
            for (Player p : Bukkit.getOnlinePlayers()) {
                if (!plugin.staffManager.isStaff(p)) p.hidePlayer(plugin, staff);
            }
            return true;
        } else {
            for (Player p : Bukkit.getOnlinePlayers()) {
                if (!plugin.staffManager.isStaff(p)) p.showPlayer(plugin, staff);
            }
            return false;
        }
    }

    @EventHandler
    public void onInventoryClick(InventoryClickEvent e) {
        if (!(e.getWhoClicked() instanceof Player)) return;
        Player staff = (Player) e.getWhoClicked();
        if (!plugin.staffManager.isStaff(staff)) return;
        Inventory inv = e.getInventory();
        if (inv == null) return;
        String title = e.getView().getTitle();
        if (title == null) return;

        e.setCancelled(true);

        if (title.equals("Ban Menu")) {
            ItemStack clicked = e.getCurrentItem();
            if (clicked == null) { staff.closeInventory(); return; }
            ItemMeta meta = clicked.getItemMeta();
            if (meta == null) { staff.closeInventory(); return; }
            String preset = meta.getDisplayName();
            UUID targetUUID = plugin.banManager.pendingBan.remove(staff.getUniqueId());
            if (targetUUID == null) { staff.sendMessage("Objetivo no encontrado."); staff.closeInventory(); return; }
            long millis = BanManager.presetToMillis(preset);
            plugin.banManager.banPlayer(targetUUID, staff.getName(), "Baneado por staff (" + preset + ")", millis);
            staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Jugador baneado (" + preset + ").");
            staff.closeInventory();
            return;
        }

        if (title.equals("TP Menu")) {
            ItemStack clicked = e.getCurrentItem();
            if (clicked == null) { staff.closeInventory(); return; }
            Player target = plugin.tpManager.getPlayerFromItem(clicked);
            if (target != null && target.isOnline()) {
                staff.teleport(target);
                staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Teletransportado a " + target.getName());
            }
            staff.closeInventory();
            return;
        }

        if (title.equals("Warn Menu")) {
            ItemStack clicked = e.getCurrentItem();
            if (clicked == null) { staff.closeInventory(); return; }
            ItemMeta meta = clicked.getItemMeta();
            if (meta == null) { staff.closeInventory(); return; }
            String preset = meta.getDisplayName();
            staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Warn enviado: " + preset);
            staff.closeInventory();
            return;
        }

        if (title.equals("Troll Menu")) {
            ItemStack clicked = e.getCurrentItem();
            if (clicked == null) { staff.closeInventory(); return; }
            ItemMeta meta = clicked.getItemMeta();
            if (meta == null) { staff.closeInventory(); return; }
            String action = meta.getDisplayName();
            staff.sendMessage(plugin.getConfig().getString("messages.prefix","[STAFF] ") + "Acción de trolleo: " + action);
            staff.closeInventory();
            return;
        }
    }
}
EOF

# ---------------------------
# Fin del script
# ---------------------------
echo "Contenido generado en proyecto ${PROJECT}. Revisa la carpeta ${PROJECT}."
echo "Ahora entra en Gitpod con el repo abierto, ejecuta estos scripts y haz commit/push de los archivos generados."
