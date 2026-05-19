import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../services/products_service.dart';
import '../theme/app_theme.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  Future<List<Product>>? _futureProducts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initProducts();
  }

  void _initProducts() {
    if (_futureProducts != null) return;
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      _futureProducts = ProductsService(token: token).getProducts();
    } else {
      _futureProducts = Future.error('Authentication required');
    }
  }

  Future<void> _refreshProducts() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _futureProducts = ProductsService(token: token).getProducts();
    });
    await _futureProducts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Items'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: FutureBuilder<List<Product>>(
          future: _futureProducts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is Exception ? snapshot.error.toString() : 'Failed to load products';
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(message, style: const TextStyle(color: Colors.redAccent)),
                ],
              );
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.sku.isNotEmpty) Text('SKU: ${product.sku}'),
                        if (product.brand != null && product.brand!.isNotEmpty) Text('Brand: ${product.brand}'),
                        if (product.unit != null && product.unit!.isNotEmpty) Text('Unit: ${product.unit}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (product.price != null)
                          Text('UZS ${product.price}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(product.isActive ? 'Active' : 'Inactive', style: TextStyle(color: product.isActive ? AppTheme.primary : AppTheme.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
