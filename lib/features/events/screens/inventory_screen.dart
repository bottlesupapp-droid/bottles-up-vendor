import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Add new bottle dialog
            },
          ),
        ],
      ),
      body: inventoryAsync.when(
        data: (inventory) {
          if (inventory.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.liquor, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No inventory found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add bottles to your inventory',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(inventoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final bottle = inventory[index];
                return _BottleCard(bottle: bottle);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading inventory: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(inventoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottleCard extends StatelessWidget {
  final Map<String, dynamic> bottle;

  const _BottleCard({required this.bottle});

  @override
  Widget build(BuildContext context) {
    final price = bottle['price'] as num? ?? 0;
    final quantity = bottle['quantity'] as int? ?? 0;
    final volume = bottle['volume'] as int? ?? 750;
    final isFeatured = bottle['featured'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Bottle Image
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: bottle['imageUrl'] != null
                    ? DecorationImage(
                        image: NetworkImage(bottle['imageUrl']),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {},
                      )
                    : null,
                color: bottle['imageUrl'] == null 
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : null,
              ),
              child: bottle['imageUrl'] == null
                  ? Icon(
                      Icons.liquor,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    )
                  : null,
            ),

            const SizedBox(width: 16),

            // Bottle Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Featured Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bottle['brand'] ?? 'Unknown Brand',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                        ),
                      ),
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEATURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Bottle Name
                  Text(
                    bottle['name'] ?? 'Unknown Bottle',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 8),

                  // Description
                  if (bottle['description'] != null)
                    Text(
                      bottle['description'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 12),

                  // Price, Volume & Quantity
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '\$${price.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volume',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${volume}ml',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'In Stock',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: quantity > 5 
                                  ? Colors.green.withOpacity(0.1)
                                  : quantity > 0 
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: quantity > 5 
                                    ? Colors.green
                                    : quantity > 0 
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: quantity > 5 
                                    ? Colors.green
                                    : quantity > 0 
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: Edit bottle dialog
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // TODO: Delete confirmation dialog
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 